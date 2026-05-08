#!/bin/bash
# Bash script to set up and run the PPP Map project with Docker Compose
# This script copies the docker-compose.yml to the workspace root and runs it

# Parse command line arguments
UP=false
DOWN=false
BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -Up|--up)
            UP=true
            shift
            ;;
        -Down|--down)
            DOWN=true
            shift
            ;;
        -Build|--build)
            BUILD=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
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

# Function to run docker-compose
run_docker_compose() {
    local command=$1
    (
        cd "$WORKSPACE_ROOT"
        docker-compose $command
    )
}

# Main logic
if [ "$UP" = true ]; then
    copy_compose_file
    run_docker_compose "up -d"
elif [ "$DOWN" = true ]; then
    copy_compose_file
    run_docker_compose "down"
elif [ "$BUILD" = true ]; then
    copy_compose_file
    run_docker_compose "build"
else
    echo "Usage: ./setup.sh [-Up] [-Down] [-Build]"
    echo "  -Up    : Copy compose file and start services"
    echo "  -Down  : Copy compose file and stop services"
    echo "  -Build : Copy compose file and build services"
    exit 1
fi
