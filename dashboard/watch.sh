#!/usr/bin/env bash
# Regenerate dashboard data every 5s. Run from the host so the DB
# (localhost:5432) and LAN LLMs are reachable.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 dashboard/generate.py --watch
