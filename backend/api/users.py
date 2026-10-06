"""Signed-in user profile.

Credentials never reach this service: the client authenticates with Firebase
and sends the resulting ID token, which :func:`require_user` verifies. The row
here only holds the profile we sync across a user's devices.
"""

from fastapi import APIRouter, Depends, HTTPException

from db.database import get_db
from db.models import User
from logger import get_logger
from schemas import UserProfile, UserProfileUpdate
from security import AuthedUser, require_user

logger = get_logger(__name__)
router = APIRouter(prefix="/users", tags=["Users"])


def _get_or_create(db, caller: AuthedUser) -> User:
    """Return the caller's row, creating it on first authenticated request."""
    user = db.query(User).filter(User.firebase_uid == caller.uid).first()
    if user:
        # Keep the email in step with Firebase (it can change there).
        if caller.email and user.email != caller.email:
            user.email = caller.email
            db.commit()
        return user

    user = User(
        firebase_uid=caller.uid,
        email=caller.email,
        name=caller.name,
        tradition="western",
    )
    db.add(user)
    try:
        db.commit()
    except Exception:
        # A concurrent first request won the race; use the row it created.
        db.rollback()
        user = db.query(User).filter(User.firebase_uid == caller.uid).first()
        if user is None:
            raise
        return user

    db.refresh(user)
    logger.info("users  created profile  uid=%s", caller.uid)
    return user


@router.get("/me", response_model=UserProfile)
def get_me(caller: AuthedUser = Depends(require_user), db=Depends(get_db)):
    """Fetch (and on first call create) the signed-in user's profile."""
    return _get_or_create(db, caller)


@router.put("/me", response_model=UserProfile)
def update_me(
    payload: UserProfileUpdate,
    caller: AuthedUser = Depends(require_user),
    db=Depends(get_db),
):
    """Update the fields the client sent; omitted fields are left untouched."""
    user = _get_or_create(db, caller)

    changes = payload.model_dump(exclude_unset=True, exclude_none=True)
    for field, value in changes.items():
        setattr(user, field, value)

    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("users  profile update failed  uid=%s: %s", caller.uid, exc)
        raise HTTPException(status_code=500, detail="Could not save profile.") from exc

    db.refresh(user)
    logger.info("users  updated profile  uid=%s  fields=%s", caller.uid, sorted(changes))
    return user


@router.delete("/me", status_code=200)
def delete_me(caller: AuthedUser = Depends(require_user), db=Depends(get_db)):
    """Erase the account: this row, the user's device tokens, and the Firebase
    credential itself, so a deletion request leaves nothing behind."""
    from db.models import DeviceToken

    deleted = (
        db.query(User).filter(User.firebase_uid == caller.uid).delete(synchronize_session=False)
    )
    db.query(DeviceToken).filter(DeviceToken.firebase_uid == caller.uid).delete(
        synchronize_session=False
    )
    db.commit()

    # Remove the login last: if this fails the user can retry, whereas deleting
    # it first could strand profile rows with no way to authenticate to them.
    credential_removed = False
    try:
        from firebase_admin import auth as fb_auth

        from firebase_app import get_app

        app = get_app()
        if app is not None:
            fb_auth.delete_user(caller.uid, app=app)
            credential_removed = True
    except Exception as exc:
        logger.error("users  firebase credential delete failed  uid=%s: %s", caller.uid, exc)

    logger.info("users  deleted account  uid=%s  rows=%d  credential=%s",
                caller.uid, deleted, credential_removed)
    return {"status": "deleted", "credentialRemoved": credential_removed}
