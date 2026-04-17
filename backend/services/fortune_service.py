"""Fortune generation templates and logic."""

import random

from logger import get_logger

logger = get_logger(__name__)

# Fortune templates
FORTUNE_TEMPLATES = {
    "Love": [
        "The stars whisper of a deep connection forming in your life. Open your heart to the unexpected, for love often arrives in disguises we don't recognize.",
        "Venus casts her golden light upon your path. A meaningful conversation today could change the course of your romantic journey forever.",
        "The universe prepares a beautiful surprise in matters of the heart. Trust the timing — what's meant for you will never pass you by.",
        "An old flame may reignite, or a new spark will catch fire. Your magnetic energy draws admirers close. Choose with your heart, but let wisdom guide you.",
        "Love transforms you today. Whether giving or receiving, the energy you share creates ripples across the cosmos. Be bold in expressing your feelings.",
    ],
    "Career": [
        "A golden opportunity approaches from an unexpected direction. Your skills are being noticed by those who matter. Stay prepared — success favors the ready.",
        "The planets align to boost your professional reputation. A bold move today could define your career trajectory for months to come.",
        "Your creative ideas have the power to reshape your work landscape. Present them with confidence. The universe rewards those who dare to innovate.",
        "A mentor or powerful ally enters your professional sphere. Their guidance opens doors you didn't know existed. Be receptive to wisdom from unexpected sources.",
        "Financial abundance flows toward you. Your hard work compounds into remarkable results. Stay disciplined and focused — the harvest season approaches.",
    ],
    "Health": [
        "The cosmos urge you to prioritize your well-being. Listen to your body's whispers before they become shouts. A small change in routine brings profound benefits.",
        "Healing energy surrounds you today. Your body has remarkable wisdom — trust its signals. Rest when needed, move when inspired, and nourish yourself with intention.",
        "The stars illuminate a path to vitality. An ancient practice or natural remedy catches your attention — follow this curiosity. Your body and mind seek balance.",
        "Your energy levels rise with the moon's influence. Channel this vitality into movement and connection with nature. The earth heals what the mind cannot.",
        "A breakthrough in understanding your body's needs is near. Pay attention to patterns and cycles. Wellness is not a destination but a daily practice of self-love.",
    ],
    "Wealth": [
        "Jupiter's generous influence opens channels of abundance. An investment of time or resources pays dividends beyond expectation. Trust your financial instincts today.",
        "The universe conspires to improve your material circumstances. A forgotten asset or unexpected income stream reveals itself. Stay open to unconventional sources of wealth.",
        "Your relationship with abundance transforms today. Release scarcity thinking and embrace the flow of prosperity. What you believe about money becomes your reality.",
        "A financial decision you've been pondering finds clarity. The stars favor bold but calculated moves. Wealth comes to those who respect it and share it wisely.",
        "Seeds of prosperity you planted in the past begin to bloom. Patience with your financial journey is rewarded. Abundance is your birthright — claim it with gratitude.",
    ],
    "Spiritual": [
        "The veil between worlds thins today. Pay attention to signs, synchronicities, and dreams. Your spiritual guides communicate through subtle channels — are you listening?",
        "A profound insight about your life's purpose crystallizes. Meditation or quiet contemplation reveals truths that busy minds miss. Your soul knows the way — follow it.",
        "The universe invites you into a deeper understanding of your cosmic role. Every experience has been preparation for this moment of awakening. Trust the divine plan.",
        "Your intuitive gifts strengthen under today's celestial influence. Trust the whispers of your higher self. Spiritual growth often comes disguised as ordinary moments.",
        "A karmic cycle completes, freeing you for new spiritual adventures. Release what you've outgrown with gratitude. Your soul expands into new dimensions of awareness.",
    ],
}


def generate_fortune(zodiac_sign: str, topic: str, mood: str, db=None) -> str:
    """
    Generate a fortune for the given sign, topic, and mood.

    Resolution order:
    1. Pre-generated daily pool in SQLite (pick one of 3 variants at random).
    2. Real-time AI generation (if pool miss and API key configured).
    3. Static template fallback.
    """
    logger.debug("generate_fortune  sign=%s  topic=%s  mood=%s", zodiac_sign, topic, mood)

    # ── 1. DB pool ────────────────────────────────────────────────────────────
    if db is not None:
        try:
            from datetime import date as _date
            from db.models import FortunePool
            today_str = _date.today().isoformat()
            pool_row = (
                db.query(FortunePool)
                .filter(
                    FortunePool.date == today_str,
                    FortunePool.zodiac_sign == zodiac_sign,
                    FortunePool.topic == topic,
                )
                .first()
            )
            if pool_row and pool_row.fortunes:
                chosen = random.choice(pool_row.fortunes)
                logger.info("generate_fortune  POOL HIT  sign=%s  topic=%s", zodiac_sign, topic)
                return chosen
            else:
                logger.debug("generate_fortune  POOL MISS  sign=%s  topic=%s", zodiac_sign, topic)
        except Exception as exc:
            logger.warning("generate_fortune  DB pool query failed (%s)", exc)

    # ── 2. Real-time AI ───────────────────────────────────────────────────────
    try:
        from services.ai_service import generate_fortune as ai_fortune
        result = ai_fortune(zodiac_sign, topic, mood)
        if result:
            logger.info("generate_fortune  AI OK  sign=%s  topic=%s", zodiac_sign, topic)
            return result
        logger.warning("generate_fortune  AI returned empty  sign=%s  topic=%s", zodiac_sign, topic)
    except Exception as exc:
        logger.warning("generate_fortune  AI exception (%s)  sign=%s — using template", exc, zodiac_sign)

    # ── 3. Static fallback ────────────────────────────────────────────────────
    fortunes = FORTUNE_TEMPLATES.get(topic, FORTUNE_TEMPLATES["Spiritual"])
    chosen = random.choice(fortunes)
    logger.debug("generate_fortune  STATIC FALLBACK  topic=%s", topic)
    return chosen
