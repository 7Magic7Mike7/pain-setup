#!/bin/bash
# Bash script to initialize, fill, test, and reset the pain database

# Parse command line arguments
INIT=false
FILL=false
TEST=false
RESET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -Init|--init)
            INIT=true
            shift
            ;;
        -Fill|--fill)
            FILL=true
            shift
            ;;
        -Test|--test)
            TEST=true
            shift
            ;;
        -Reset|--reset)
            RESET=true
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
COMPOSE_FILE="$WORKSPACE_ROOT/docker-compose.yml"

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: Compose file not found at $COMPOSE_FILE. Run ./setup.sh -Up first to generate it." >&2
    exit 1
fi

# Get the pain-db container ID
CONTAINER_ID=$(docker compose -f "$COMPOSE_FILE" ps -q pain-db)
echo "Found pain-db container with ID: $CONTAINER_ID"

# Check if container is running
if [ -z "$CONTAINER_ID" ]; then
    echo "Error: No running pain-db container found. Start the stack first with ./setup.sh -Up" >&2
    exit 1
fi

# Execute the appropriate command
if [ "$INIT" = true ]; then
    echo "Initializing database schema..."
    docker exec -it "$CONTAINER_ID" psql -U postgres -d pain_db -c "CREATE TABLE DummyPain (id SERIAL PRIMARY KEY, x FLOAT NOT NULL, y FLOAT NOT NULL, value FLOAT, datatype TEXT NOT NULL, painorigin TEXT);"

elif [ "$FILL" = true ]; then
    CSV_FILE="$WORKSPACE_ROOT/pain/data/dummy/db_data.csv"
    DEST="/tmp/db_data.csv"
    
    echo "Filling database with dummy data..."
    docker cp "$CSV_FILE" "$CONTAINER_ID:$DEST"
    docker exec "$CONTAINER_ID" psql -U postgres -d pain_db -c "COPY DummyPain FROM '$DEST' CSV HEADER;"
    echo "Imported data from $CSV_FILE into DummyPain table"

elif [ "$TEST" = true ]; then
    echo "Testing database connection and contents..."
    docker exec -it "$CONTAINER_ID" psql -U postgres -d pain_db -c "SELECT * FROM DummyPain LIMIT 7;"

elif [ "$RESET" = true ]; then
    echo "Resetting database..."
    docker exec -it "$CONTAINER_ID" psql -U postgres -d pain_db -c "DROP TABLE IF EXISTS DummyPain;"

else
    echo "Usage: ./populate-db.sh [-Init] [-Fill] [-Test] [-Reset]"
    echo "  -Init  : Initialize database schema (run once)"
    echo "  -Fill  : Fill database with dummy data (run after init)"
    echo "  -Test  : Test database connection and contents"
    echo "  -Reset : Reset database by dropping the DummyPain table"
    exit 1
fi
