#!/bin/bash

# CosmicGuide Backend Server Manager
# Usage: ./server.sh [start|stop|restart|status]

BACKEND_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$BACKEND_DIR/.server.pid"
PORT=8000

start() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Server is already running (PID: $(cat "$PID_FILE"))"
        echo "http://127.0.0.1:$PORT"
        return 1
    fi

    echo "Starting CosmicGuide backend on port $PORT..."
    source "$BACKEND_DIR/venv/bin/activate"
    uvicorn main:app --reload --port "$PORT" --app-dir "$BACKEND_DIR" >> "$BACKEND_DIR/backend.log" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 1

    if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Server started (PID: $(cat "$PID_FILE"))"
        echo "API:  http://127.0.0.1:$PORT"
        echo "Docs: http://127.0.0.1:$PORT/docs"
        echo "Logs: tail -f $BACKEND_DIR/backend.log"
    else
        echo "Failed to start server"
        rm -f "$PID_FILE"
        return 1
    fi
}

kill_port() {
    local pids
    pids=$(lsof -ti :"$PORT" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo "$pids" | xargs kill -9 2>/dev/null
        sleep 1
    fi
}

stop() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        echo "Stopping server (PID: $pid)..."
        kill "$pid" 2>/dev/null
        sleep 1
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null
            sleep 1
        fi
        rm -f "$PID_FILE"
    fi

    # Kill anything still on the port
    local remaining
    remaining=$(lsof -ti :"$PORT" 2>/dev/null)
    if [ -n "$remaining" ]; then
        echo "Cleaning up processes on port $PORT..."
        echo "$remaining" | xargs kill -9 2>/dev/null
        sleep 1
        echo "Server stopped"
    elif [ -f "$PID_FILE" ] || [ -n "${pid:-}" ]; then
        echo "Server stopped"
    else
        echo "Server is not running"
    fi
    rm -f "$PID_FILE"
}

status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Server is running (PID: $(cat "$PID_FILE"))"
        echo "http://127.0.0.1:$PORT"
    else
        local pid
        pid=$(lsof -ti :"$PORT" 2>/dev/null)
        if [ -n "$pid" ]; then
            echo "Server is running on port $PORT (PID: $pid) — not managed by this script"
        else
            echo "Server is not running"
        fi
        rm -f "$PID_FILE"
    fi
}

    case "${1:-}" in
    start)   start ;;
    stop)    stop ;;
    restart) stop && sleep 2 && start ;;
    status)  status ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
