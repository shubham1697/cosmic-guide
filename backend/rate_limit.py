"""Per-IP request throttling.

The horoscope/compatibility/kundli routes are unauthenticated and spend a real
LLM call whenever the requested combination misses the cache, so an open API is
an open invoice. This keeps a fixed window per client in process memory.

Single worker only — state is not shared between processes. That matches the
current deployment (UVICORN_WORKERS=1, required by the scheduler); put Redis or
similar behind it before scaling out.
"""

import time
from threading import Lock

from fastapi import Request
from fastapi.responses import JSONResponse

from config import settings
from logger import get_logger

logger = get_logger(__name__)

WINDOW_SECONDS = 60

# Ceiling on tracked clients so a flood of spoofed/rotating IPs cannot grow the
# table without bound. Pruning only drops windows that have already expired.
_MAX_TRACKED_KEYS = 20_000

# Never throttle liveness probes — a rate-limited health check reads as an
# outage and can get the container killed.
_EXEMPT_PATHS = frozenset({"/health", "/", "/docs", "/redoc", "/openapi.json"})

# Routes that can reach the LLM on a cache miss.
_LLM_PREFIXES = (
    f"{settings.API_PREFIX}/horoscope",
    f"{settings.API_PREFIX}/compatibility",
    f"{settings.API_PREFIX}/kundli",
    f"{settings.API_PREFIX}/vedic",
    f"{settings.API_PREFIX}/chart",
)


class FixedWindowLimiter:
    """Counts hits per (bucket, client) inside a wall-clock aligned window."""

    def __init__(self) -> None:
        self._hits: dict[tuple[str, str], tuple[float, int]] = {}
        self._lock = Lock()

    def hit(self, bucket: str, client: str, limit: int, now: float) -> tuple[bool, int]:
        """Record a request. Returns (allowed, seconds_until_window_resets)."""
        window_start = now - (now % WINDOW_SECONDS)
        key = (bucket, client)

        with self._lock:
            started, count = self._hits.get(key, (0.0, 0))
            if started != window_start:
                started, count = window_start, 0
            count += 1
            self._hits[key] = (started, count)

            if len(self._hits) > _MAX_TRACKED_KEYS:
                self._prune(window_start)

        retry_after = max(1, int(window_start + WINDOW_SECONDS - now))
        return count <= limit, retry_after

    def _prune(self, window_start: float) -> None:
        """Caller must hold the lock."""
        stale = [key for key, (started, _) in self._hits.items() if started < window_start]
        for key in stale:
            del self._hits[key]
        if not stale:
            # Everything is in the current window; drop it all rather than
            # letting the table grow unbounded under a distributed flood.
            self._hits.clear()
            logger.warning(
                "Rate limiter tracking table exceeded %d live keys — cleared.",
                _MAX_TRACKED_KEYS,
            )


_limiter = FixedWindowLimiter()


def client_identity(request: Request) -> str:
    """Best available client identifier.

    X-Forwarded-For is only honoured when TRUST_PROXY_HEADERS is set, because a
    direct caller can set it freely and mint a new bucket on every request.
    """
    if settings.TRUST_PROXY_HEADERS:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _bucket_for(path: str) -> tuple[str, int]:
    if path.startswith(_LLM_PREFIXES):
        return "llm", settings.RATE_LIMIT_LLM
    return "default", settings.RATE_LIMIT_DEFAULT


async def rate_limit_middleware(request: Request, call_next):
    if not settings.RATE_LIMIT_ENABLED or request.method == "OPTIONS":
        return await call_next(request)

    path = request.url.path
    if path in _EXEMPT_PATHS:
        return await call_next(request)

    bucket, limit = _bucket_for(path)
    client = client_identity(request)
    allowed, retry_after = _limiter.hit(bucket, client, limit, time.time())

    if not allowed:
        logger.warning(
            "Rate limit hit — client=%s bucket=%s limit=%d/min path=%s",
            client, bucket, limit, path,
        )
        return JSONResponse(
            status_code=429,
            content={"detail": "Too many requests. Please slow down and try again shortly."},
            headers={"Retry-After": str(retry_after)},
        )

    return await call_next(request)
