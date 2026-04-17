"""
Centralised logging configuration for CosmicGuide API.

Set the LOG_LEVEL environment variable to control verbosity:
  DEBUG   — every AI prompt/response, cache hits, DB queries
  INFO    — normal request flow, AI generation summaries  (default)
  WARNING — only degraded behaviour (fallbacks, slow calls)
  ERROR   — failures only

Usage (in any module):
    from logger import get_logger
    logger = get_logger(__name__)
"""

import logging
import sys
from config import settings

_CONFIGURED = False


def configure_logging() -> None:
    """Call once at startup (main.py already does this)."""
    global _CONFIGURED
    if _CONFIGURED:
        return

    level_name = settings.LOG_LEVEL.upper()
    level = getattr(logging, level_name, logging.INFO)

    fmt = (
        "%(asctime)s | %(levelname)-8s | %(name)-35s | %(message)s"
        if level <= logging.DEBUG
        else "%(asctime)s | %(levelname)-8s | %(message)s"
    )

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter(fmt, datefmt="%Y-%m-%d %H:%M:%S"))

    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(level)

    # Silence noisy third-party libraries unless we're in DEBUG
    if level > logging.DEBUG:
        for noisy in ("uvicorn.access", "httpx", "httpcore", "google", "urllib3"):
            logging.getLogger(noisy).setLevel(logging.WARNING)

    _CONFIGURED = True


def get_logger(name: str) -> logging.Logger:
    """Return a named logger. configure_logging() must have been called first."""
    return logging.getLogger(name)
