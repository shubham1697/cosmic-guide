#!/bin/bash

# CosmicGuide Backend Server Manager
# Usage: ./server.sh [start|stop|restart|status]

BACKEND_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$BACKEND_DIR/.." && pwd)"
PID_FILE="$BACKEND_DIR/.server.pid"
PORT=8000
DOCKER_SERVICES="db backend adminer"

ensure_docker_services() {
    echo "Checking Docker services ($DOCKER_SERVICES)..."
    local all_running=true
    for svc in $DOCKER_SERVICES; do
        if ! docker compose -f "$PROJECT_DIR/docker-compose.yml" ps --status running "$svc" 2>/dev/null | grep -q "$svc"; then
            all_running=false
            break
        fi
    done

    if [ "$all_running" = true ]; then
        echo "Docker services are already running."
    else
        echo "Starting Docker services..."
        docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d $DOCKER_SERVICES
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
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
