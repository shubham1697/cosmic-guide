-- ============================================================================
-- CosmicGuide Content Database — PostgreSQL init script
-- Auto-executed when the Docker container starts for the first time.
-- ============================================================================

-- Content tables only (no users/kundli — those stay on the API server)

CREATE TABLE IF NOT EXISTS horoscopes (
    id          SERIAL PRIMARY KEY,
    date        VARCHAR(10) NOT NULL,
    zodiac_sign VARCHAR(20) NOT NULL,
    general     TEXT,
    love        TEXT,
    career      TEXT,
    health      TEXT,
    overall_score INTEGER,
    lucky_number  INTEGER,
    lucky_color   VARCHAR(50),
    mood          VARCHAR(50),
    created_at    TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_horoscopes_date ON horoscopes(date);
CREATE INDEX IF NOT EXISTS idx_horoscopes_sign ON horoscopes(zodiac_sign);
CREATE UNIQUE INDEX IF NOT EXISTS idx_horoscopes_date_sign ON horoscopes(date, zodiac_sign);

CREATE TABLE IF NOT EXISTS fortune_pool (
    id          SERIAL PRIMARY KEY,
    date        VARCHAR(10) NOT NULL,
    zodiac_sign VARCHAR(20) NOT NULL,
    topic       VARCHAR(50) NOT NULL,
    fortunes    JSONB NOT NULL,
    created_at  TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_fortune_pool_date ON fortune_pool(date);
CREATE INDEX IF NOT EXISTS idx_fortune_pool_sign ON fortune_pool(zodiac_sign);
CREATE INDEX IF NOT EXISTS idx_fortune_pool_topic ON fortune_pool(topic);
CREATE UNIQUE INDEX IF NOT EXISTS idx_fortune_pool_date_sign_topic ON fortune_pool(date, zodiac_sign, topic);

CREATE TABLE IF NOT EXISTS stories (
    id           SERIAL PRIMARY KEY,
    title        VARCHAR(255) NOT NULL,
    summary      TEXT,
    content      TEXT,
    category     VARCHAR(50),
    read_time    VARCHAR(20),
    author       VARCHAR(100),
    published_at TIMESTAMP DEFAULT NOW(),
    is_featured  BOOLEAN DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_stories_category ON stories(category);
CREATE INDEX IF NOT EXISTS idx_stories_published ON stories(published_at);

CREATE TABLE IF NOT EXISTS compatibility (
    id          SERIAL PRIMARY KEY,
    sign1       VARCHAR(20) NOT NULL,
    sign2       VARCHAR(20) NOT NULL,
    score       INTEGER,
    description TEXT,
    love_advice TEXT,
    strengths   TEXT,
    challenges  TEXT
);
CREATE INDEX IF NOT EXISTS idx_compat_sign1 ON compatibility(sign1);
CREATE INDEX IF NOT EXISTS idx_compat_sign2 ON compatibility(sign2);
CREATE UNIQUE INDEX IF NOT EXISTS idx_compat_pair ON compatibility(sign1, sign2);

CREATE TABLE IF NOT EXISTS tarot_cards (
    id                      SERIAL PRIMARY KEY,
    name                    VARCHAR(100) UNIQUE NOT NULL,
    number                  VARCHAR(10),
    meaning                 TEXT,
    upright_interpretation  TEXT,
    reversed_interpretation TEXT
);

CREATE TABLE IF NOT EXISTS fortune_history (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER,
    zodiac_sign VARCHAR(20),
    topic       VARCHAR(50),
    mood        VARCHAR(50),
    fortune_text TEXT,
    created_at   TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_fortune_history_user ON fortune_history(user_id);

-- Cleanup helper: delete content older than N days (call from a cron/maintenance script)
CREATE OR REPLACE FUNCTION cleanup_old_content(days_to_keep INTEGER DEFAULT 30)
RETURNS TABLE(horoscopes_deleted BIGINT, fortunes_deleted BIGINT) AS $$
DECLARE
    cutoff VARCHAR(10);
BEGIN
    cutoff := TO_CHAR(NOW() - (days_to_keep || ' days')::INTERVAL, 'YYYY-MM-DD');

    DELETE FROM horoscopes WHERE date < cutoff;
    GET DIAGNOSTICS horoscopes_deleted = ROW_COUNT;

    DELETE FROM fortune_pool WHERE date < cutoff;
    GET DIAGNOSTICS fortunes_deleted = ROW_COUNT;

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;
