#!/bin/bash

# CosmicGuide Backend Server Manager
# Usage: ./server.sh [start|stop|restart|status|logs] [--build|-b]
#   --build, -b   Rebuild Docker images before starting (use after code changes)

BACKEND_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$BACKEND_DIR/.." && pwd)"
PID_FILE="$BACKEND_DIR/.server.pid"
PORT=8000
DOCKER_SERVICES="db backend adminer"

# Parse optional flags (accepted in any position)
BUILD=false
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --build|-b) BUILD=true ;;
        *) ARGS+=("$arg") ;;
    esac
done
set -- "${ARGS[@]}"

ensure_docker_services() {
    local build_flag=""
    if [ "$BUILD" = true ]; then
        build_flag="--build"
    fi

    echo "Checking Docker services ($DOCKER_SERVICES)..."
    local all_running=true
    for svc in $DOCKER_SERVICES; do
        if ! docker compose -f "$PROJECT_DIR/docker-compose.yml" ps --status running "$svc" 2>/dev/null | grep -q "$svc"; then
            all_running=false
            break
        fi
    done

    if [ "$all_running" = true ] && [ "$BUILD" != true ]; then
        echo "Docker services are already running."
    else
        if [ "$BUILD" = true ]; then
            echo "Rebuilding and starting Docker services..."
        else
            echo "Starting Docker services..."
        fi
        docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d $build_flag $DOCKER_SERVICES
        echo "Docker services started."
        echo "  DB:      localhost:5432"
        echo "  API:     http://localhost:$PORT"
        echo "  Adminer: http://localhost:8080"
    fi
}

start() {
    ensure_docker_services
}


stop() {
    echo "Stopping Docker services..."
    docker compose -f "$PROJECT_DIR/docker-compose.yml" stop $DOCKER_SERVICES
    echo "Docker services stopped."
}

status() {
    echo "Docker services status:"
    docker compose -f "$PROJECT_DIR/docker-compose.yml" ps $DOCKER_SERVICES
}

    case "${1:-}" in
    start)   start ;;
    stop)    stop ;;
    restart) stop && sleep 2 && start ;;
    status)  status ;;
    logs)    docker compose -f "$PROJECT_DIR/docker-compose.yml" logs -f $DOCKER_SERVICES ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs} [--build|-b]"
        echo "  --build, -b   Rebuild Docker images before starting (use after code changes)"
        exit 1
        ;;
esac
