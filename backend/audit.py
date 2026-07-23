"""
Audit logging for all network traffic in CosmicGuide.

Produces a dedicated, structured (JSON-lines) audit trail that is kept
separate from the human-readable application log.  Two kinds of events are
recorded:

  * inbound  — every HTTP request served by the FastAPI app
  * outbound — every external API call the backend makes (Gemini / Ollama /
               iPhone LLM, etc.)

Each inbound request is assigned a correlation id (``request_id``).  That id
is stored in a ``contextvars.ContextVar`` so any outbound calls triggered
while handling the request are stamped with the same id, letting you trace a
single user request across every network hop it caused.

Records are written to ``logs/audit.log`` (rotated) and echoed to stdout so
they also appear in ``docker logs``.  Only metadata is recorded — request and
response bodies are never logged, and sensitive headers are redacted.
"""

import json
import logging
import os
import uuid
from contextvars import ContextVar
from datetime import datetime, timezone
from logging.handlers import RotatingFileHandler
from typing import Optional

# ── correlation id shared across inbound + outbound events ────────────────────
_request_id_ctx: ContextVar[Optional[str]] = ContextVar("audit_request_id", default=None)

# Headers that must never be written to the audit trail.
_SENSITIVE_HEADERS = {
    "authorization",
    "proxy-authorization",
    "cookie",
    "set-cookie",
    "x-api-key",
    "api-key",
    "x-gemini-api-key",
}

_AUDIT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs")
_AUDIT_FILE = os.path.join(_AUDIT_DIR, "audit.log")

_configured = False


def _get_audit_logger() -> logging.Logger:
    """Return the dedicated audit logger, configuring it once on first use."""
    global _configured
    audit_logger = logging.getLogger("cosmicguide.audit")
    if _configured:
        return audit_logger

    # Audit records stand alone — don't leak them into the root app log.
    audit_logger.propagate = False
    audit_logger.setLevel(logging.INFO)

    formatter = logging.Formatter("%(message)s")

    # Persisted, rotated JSON-lines file (survives via the ./backend volume).
    try:
        os.makedirs(_AUDIT_DIR, exist_ok=True)
        file_handler = RotatingFileHandler(
            _AUDIT_FILE, maxBytes=10 * 1024 * 1024, backupCount=5, encoding="utf-8"
        )
        file_handler.setFormatter(formatter)
        audit_logger.addHandler(file_handler)
    except OSError:
        # If the log dir isn't writable we still want stdout auditing below.
        pass

    # Mirror to stdout so records are visible in `docker logs`.
    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(logging.Formatter("AUDIT %(message)s"))
    audit_logger.addHandler(stream_handler)

    _configured = True
    return audit_logger


def new_request_id() -> str:
    """Generate a fresh correlation id."""
    return uuid.uuid4().hex


def set_request_id(request_id: str) -> None:
    """Bind a correlation id to the current context (inbound middleware)."""
    _request_id_ctx.set(request_id)


def get_request_id() -> Optional[str]:
    """Return the correlation id bound to the current context, if any."""
    return _request_id_ctx.get()


def redact_headers(headers: dict) -> dict:
    """Return a copy of ``headers`` with sensitive values masked."""
    redacted = {}
    for key, value in headers.items():
        redacted[key] = "***REDACTED***" if key.lower() in _SENSITIVE_HEADERS else value
    return redacted


def _emit(record: dict) -> None:
    record["ts"] = datetime.now(timezone.utc).isoformat(timespec="milliseconds")
    _get_audit_logger().info(json.dumps(record, default=str, ensure_ascii=False))


def audit_inbound(
    *,
    request_id: str,
    method: str,
    path: str,
    query: str = "",
    client_ip: str = "unknown",
    user_agent: str = "",
    status_code: Optional[int] = None,
    duration_ms: float = 0.0,
    request_bytes: Optional[int] = None,
    response_bytes: Optional[int] = None,
    error: Optional[str] = None,
) -> None:
    """Write an audit record for one inbound HTTP request."""
    _emit(
        {
            "type": "inbound",
            "request_id": request_id,
            "client_ip": client_ip,
            "method": method,
            "path": path,
            "query": query,
            "user_agent": user_agent,
            "status": status_code,
            "duration_ms": round(duration_ms, 1),
            "req_bytes": request_bytes,
            "resp_bytes": response_bytes,
            "error": error,
        }
    )


def audit_outbound(
    *,
    service: str,
    method: str,
    url: str,
    status_code: Optional[int] = None,
    duration_ms: float = 0.0,
    request_summary: Optional[str] = None,
    response_preview: Optional[str] = None,
    response_chars: Optional[int] = None,
    error: Optional[str] = None,
) -> None:
    """Write an audit record for one outbound external API call.

    ``url`` should be the full destination (host + path) so the trail shows
    exactly where the call went.  ``response_preview`` captures what came back
    (truncated) while ``response_chars`` records the true length of the full
    response.
    """
    _emit(
        {
            "type": "outbound",
            "request_id": get_request_id(),
            "service": service,
            "method": method,
            "url": url,
            "status": status_code,
            "duration_ms": round(duration_ms, 1),
            "request": request_summary,
            "response_chars": response_chars,
            "response_preview": response_preview,
            "error": error,
        }
    )
