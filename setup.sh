#!/bin/bash
# Bash script to set up and run the PPP Map project with Docker Compose
# This script copies the docker-compose.yml to the workspace root and runs it

# Parse command line arguments
UP=false
DOWN=false
BUILD=false
LOGS=false

show_help() {
    echo "Usage: ./setup.sh [--build] [--up] [--down]"
    echo "  --build : Copy compose file and build services"
    echo "  --up    : Copy compose file and start services"
    echo "  --down  : Copy compose file and stop services"
    echo "  --logs  : Follows the container logs"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -Up|--up|--u)
            UP=true
            shift
            ;;
        -Down|--down|--d)
            DOWN=true
            shift
            ;;
        -Build|--build|--b)
            BUILD=true
            shift
            ;;
        --logs)
            LOGS=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Get the script directory and workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
TARGET_COMPOSE="$WORKSPACE_ROOT/docker-compose.yml"

# Function to copy the docker-compose file
copy_compose_file() {
    cp "$COMPOSE_FILE" "$TARGET_COMPOSE"
    echo "Copied docker-compose.yml to workspace root"
}

# Function to run docker compose
run_docker_compose() {
    local command=$1
    (
        cd "$WORKSPACE_ROOT"
        docker compose $command
    )
}

# Main logic
EXEC_COMMAND=false
if [ "$BUILD" = true ]; then
    copy_compose_file
    run_docker_compose "build"
    EXEC_COMMAND=true
fi
if [ "$UP" = true ]; then
    copy_compose_file
    run_docker_compose "up -d"
    EXEC_COMMAND=true
elif [ "$DOWN" = true ]; then
    copy_compose_file
    run_docker_compose "down"
    EXEC_COMMAND=true
elif [ "$LOGS" = true ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
    COMPOSE_FILE="$WORKSPACE_ROOT/docker-compose.yml"
    CONTAINER_ID=$(docker compose -f "$COMPOSE_FILE" ps -q pain-server)
    docker logs -f ${CONTAINER_ID}
fi

if [ "$EXEC_COMMAND" = false ]; then
    show_help
fi
