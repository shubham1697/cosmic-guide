#!/usr/bin/env python3
"""
Standalone script to generate astrology stories via Ollama and seed the DB.

Usage (from the backend/ directory):
    python3 seed_stories.py

What it does:
  1. Clears existing stories from the DB.
  2. Calls Ollama (mistral:latest) for each of 6 categories.
  3. Saves each story to the DB as it's generated.
  4. Writes all stories to data/mock/stories_data.py.
"""

import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

import logger
logger.configure_logging()

from logger import get_logger
log = get_logger("seed_stories")

from db.database import engine, SessionLocal
from db.models import Base, Story
from services.story_service import seed_stories_db, STORY_CATEGORIES

# Ensure tables exist
Base.metadata.create_all(engine)

db = SessionLocal()
try:
    existing = db.query(Story).count()
    if existing:
        log.info("Clearing %d existing stories...", existing)
        db.query(Story).delete()
        db.commit()

    log.info("Starting generation for %d categories: %s", len(STORY_CATEGORIES), STORY_CATEGORIES)
    log.info("This may take several minutes depending on Ollama speed.\n")

    n = seed_stories_db(db)

    if n == 0:
        log.error("No stories were generated. Check Ollama is reachable at the configured URL.")
        sys.exit(1)

    log.info("\nDone! Generated %d / %d stories.", n, len(STORY_CATEGORIES))
    log.info("DB: cosmicguide.db  |  Mock: data/mock/stories_data.py")

finally:
    db.close()
