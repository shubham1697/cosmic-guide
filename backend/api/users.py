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
from security import AuthedUser, require_fresh_user, require_user

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
    caller: AuthedUser = Depends(require_fresh_user),
    db=Depends(get_db),
):
    """Update the fields the client sent; omitted fields are left untouched.

    An explicit ``null`` clears the field — that is how a user corrects or
    withdraws a birth detail, so it must stay distinguishable from "omitted".
    """
    user = _get_or_create(db, caller)

    changes = payload.model_dump(exclude_unset=True)
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


def _remove_firebase_credential(uid: str) -> bool:
    """Delete the Firebase login. Already-absent counts as success so a retried
    deletion can finish rather than failing forever."""
    from firebase_admin import auth as fb_auth

    from firebase_app import get_app

    app = get_app()
    if app is None:
        return False
    try:
        fb_auth.delete_user(uid, app=app)
        return True
    except fb_auth.UserNotFoundError:
        return True
    except Exception as exc:
        logger.error("users  firebase credential delete failed  uid=%s: %s", uid, exc)
        return False


@router.delete("/me", status_code=200)
def delete_me(caller: AuthedUser = Depends(require_fresh_user), db=Depends(get_db)):
    """Erase the account: this row, the user's device tokens, and the Firebase
    credential itself, so a deletion request leaves nothing behind.

    The rows are removed inside an *uncommitted* transaction and only committed
    once the credential is actually gone. A failure part-way therefore leaves
    the account completely intact and the call can simply be retried — the old
    order could destroy the profile and still leave the login working.
    """
    from db.models import DeviceToken

    try:
        deleted = (
            db.query(User)
            .filter(User.firebase_uid == caller.uid)
            .delete(synchronize_session=False)
        )
        db.query(DeviceToken).filter(DeviceToken.firebase_uid == caller.uid).delete(
            synchronize_session=False
        )
        db.flush()
    except Exception as exc:
        db.rollback()
        logger.error("users  account delete failed  uid=%s: %s", caller.uid, exc)
        raise HTTPException(
            status_code=500, detail="Could not delete your account. Please try again."
        ) from exc

    if not _remove_firebase_credential(caller.uid):
        db.rollback()
        raise HTTPException(
            status_code=502,
            detail="Could not delete your sign-in. Nothing was removed — please try again.",
        )

    db.commit()
    logger.info("users  deleted account  uid=%s  rows=%d", caller.uid, deleted)
    return {"status": "deleted", "credentialRemoved": True, "rowsRemoved": deleted}
