#!/usr/bin/env bash
# Serve the dashboard so index.html can fetch data/dashboard.json.
# Usage: ./serve.sh [port]   (default 8077)
set -euo pipefail
cd "$(dirname "$0")"
PORT="${1:-8077}"
echo "CosmicGuide dashboard → http://localhost:${PORT}/"
python3 -m http.server "$PORT"
