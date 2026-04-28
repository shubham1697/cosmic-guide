#!/bin/bash
# View backend logs in real-time
# Usage: ./view_logs.sh [filter]
# Examples:
#   ./view_logs.sh              # All logs
#   ./view_logs.sh "POST"       # Only POST requests
#   ./view_logs.sh "→"          # Only incoming requests
#   ./view_logs.sh "Ollama"     # Only Ollama API calls

BACKEND_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$BACKEND_DIR/backend.log"

if [ ! -f "$LOG_FILE" ]; then
    echo "Log file not found at: $LOG_FILE"
    echo "Starting backend first..."
    cd "$BACKEND_DIR" && ./server.sh restart
    sleep 2
fi

if [ -z "$1" ]; then
    echo "Showing all logs (Ctrl+C to stop)..."
    tail -f "$LOG_FILE"
else
    echo "Showing logs matching: $1 (Ctrl+C to stop)..."
    tail -f "$LOG_FILE" | grep "$1"
fi
