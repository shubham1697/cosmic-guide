import os
import logging
import sys

# ── Database settings ─────────────────────────────────────────────────────────

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://cosmicguide:cosmicguide@localhost:5432/cosmicguide",
)

# ── Ollama settings ───────────────────────────────────────────────────────────

OLLAMA_HOST = os.getenv("OLLAMA_HOST", "192.168.29.159:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "gemma3:4b")
OLLAMA_TIMEOUT = int(os.getenv("OLLAMA_TIMEOUT", "600"))

# ── Logging ───────────────────────────────────────────────────────────────────

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()


def configure_logging() -> None:
    level = getattr(logging, LOG_LEVEL, logging.INFO)
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


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
