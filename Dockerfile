# ---- builder: compiles wheels (pyswisseph needs a C toolchain) ----
FROM python:3.12-slim AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc g++ && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY backend/requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# ---- runtime: no compilers, non-root ----
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN groupadd --system app && useradd --system --gid app --home-dir /app app

WORKDIR /app

COPY --from=builder /wheels /wheels
COPY backend/requirements.txt .
RUN pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt && \
    rm -rf /wheels

COPY backend/ .
COPY shared/ ./shared/

# audit.py writes logs/audit.log at runtime
RUN mkdir -p /app/logs && chown -R app:app /app

USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/ready', timeout=4).status == 200 else 1)"

# Keep workers at 1: main.py starts an in-process APScheduler, so every extra
# worker would fire the daily jobs again.
ENV UVICORN_WORKERS=1
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000} --workers ${UVICORN_WORKERS}"]
