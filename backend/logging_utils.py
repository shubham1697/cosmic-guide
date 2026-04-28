"""
Logging utilities for API and service calls.

Provides helpers for consistent logging of:
- External API calls (Ollama, Gemini, etc.)
- Database operations
- Service function execution
- Request/response payloads
"""

import json
import time
from typing import Any, Callable, Optional
from functools import wraps

from logger import get_logger

logger = get_logger(__name__)


def log_external_api_call(
    service_name: str,
    endpoint: str,
    method: str = "POST",
    request_data: Optional[dict] = None,
    response_data: Optional[dict] = None,
    response_text: Optional[str] = None,
    elapsed_ms: float = 0.0,
    status_code: Optional[int] = None,
    error: Optional[Exception] = None,
) -> None:
    """
    Log an external API call in a structured way.
    
    Args:
        service_name: Name of the service (e.g., "Ollama", "Gemini", "Postgres")
        endpoint: API endpoint or operation being called
        method: HTTP method or operation type
        request_data: Request payload (will be truncated)
        response_data: Response payload (will be truncated)
        response_text: Raw response text (will be truncated)
        elapsed_ms: Time taken in milliseconds
        status_code: HTTP status code if applicable
        error: Exception if call failed
    """
    # Truncate large payloads for readability
    def truncate(data: Any, max_len: int = 200) -> str:
        if isinstance(data, dict):
            s = json.dumps(data, default=str)
        elif isinstance(data, bytes):
            s = data.decode("utf-8", errors="replace")
        else:
            s = str(data)
        return s[:max_len] + ("…" if len(s) > max_len else "")
    
    if error:
        logger.error(
            "→ %s %s %s | ERROR after %.0fms | %s",
            service_name, method, endpoint, elapsed_ms, error,
        )
    elif status_code:
        level = "warning" if status_code >= 400 else "info"
        log_func = getattr(logger, level)
        req_preview = truncate(request_data) if request_data else "(no body)"
        resp_preview = truncate(response_text or response_data or "(no response)")
        log_func(
            "→ %s %s %s | status=%d %.0fms | req=%s | resp=%s",
            service_name, method, endpoint, status_code, elapsed_ms, req_preview, resp_preview,
        )
    else:
        req_preview = truncate(request_data) if request_data else "(no body)"
        resp_preview = truncate(response_text or response_data or "(no response)")
        logger.debug(
            "→ %s %s %s | %.0fms | req=%s | resp=%s",
            service_name, method, endpoint, elapsed_ms, req_preview, resp_preview,
        )


def log_db_query(
    operation: str,
    table: str,
    filter_expr: str = "",
    rows_affected: int = 0,
    elapsed_ms: float = 0.0,
    error: Optional[Exception] = None,
) -> None:
    """
    Log a database query/operation.
    
    Args:
        operation: Query type (SELECT, INSERT, UPDATE, DELETE)
        table: Table name
        filter_expr: WHERE clause or filter expression (truncated)
        rows_affected: Number of rows affected
        elapsed_ms: Time taken in milliseconds
        error: Exception if operation failed
    """
    if error:
        logger.error(
            "🗄  %s %s %s | ERROR after %.0fms | %s",
            operation, table, filter_expr, elapsed_ms, error,
        )
    elif rows_affected > 0:
        logger.debug(
            "🗄  %s %s %s | %d rows %.0fms",
            operation, table, filter_expr, rows_affected, elapsed_ms,
        )
    else:
        logger.debug(
            "🗄  %s %s %s | %.0fms",
            operation, table, filter_expr, elapsed_ms,
        )


def service_call(service_name: str, operation: str = ""):
    """
    Decorator for logging service function calls.
    
    Usage:
        @service_call("HoroscopeService", "get_daily")
        def get_horoscope(sign: str) -> dict:
            ...
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            args_str = ", ".join(
                f"{arg!r}" if not isinstance(arg, (dict, list)) else f"{type(arg).__name__}(…)"
                for arg in args[:3]  # Show first 3 args only
            )
            kwargs_str = ", ".join(f"{k}={v!r}" for k, v in list(kwargs.items())[:2])
            all_args = ", ".join(filter(None, [args_str, kwargs_str]))
            
            t0 = time.perf_counter()
            op_name = operation or func.__name__
            logger.debug("→ %s.%s(%s)", service_name, op_name, all_args)
            
            try:
                result = func(*args, **kwargs)
                elapsed_ms = (time.perf_counter() - t0) * 1000
                result_preview = str(result)[:80] if result else "None"
                logger.debug("← %s.%s OK (%.0fms) → %s", service_name, op_name, elapsed_ms, result_preview)
                return result
            except Exception as exc:
                elapsed_ms = (time.perf_counter() - t0) * 1000
                logger.error("← %s.%s ERROR (%.0fms): %s", service_name, op_name, elapsed_ms, exc)
                raise
        
        return wrapper
    return decorator
