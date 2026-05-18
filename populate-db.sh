#!/bin/bash
# Bash script to initialize, fill, test, and reset the pain database

# Parse command line arguments
if [ $# -gt 0 ]; then
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

    # Check which operation is requested
    if [ $1 == "--init" ]; then
        echo "Initializing database schema..."
        docker exec -it "$CONTAINER_ID" psql -U postgres -d pain_db -c "CREATE TABLE DummyPain (id SERIAL PRIMARY KEY, x FLOAT NOT NULL, y FLOAT NOT NULL, value FLOAT, datatype TEXT NOT NULL, painorigin TEXT);"
        exit 0

    elif [ $1 == "--fill" ]; then
        if [ $# -gt 1 ]; then
            CSV_FILE="$2"
        else
            CSV_FILE="$WORKSPACE_ROOT/pain/data/dummy/db_data.csv"
        fi
        DEST="/tmp/db_data.csv"

        echo "Filling database with dummy data..."
        docker cp "$CSV_FILE" "$CONTAINER_ID:$DEST"
        docker exec "$CONTAINER_ID" psql -U postgres -d pain_db -c "COPY DummyPain FROM '$DEST' CSV HEADER;"
        echo "Imported data from $CSV_FILE into DummyPain table"

        exit 0

    elif [ $1 == "--test" ]; then
        echo "Testing database connection and contents..."
        if [ $# -gt 1 ]; then
            LIMIT="$2"
        else
            LIMIT="7"
        fi
        docker exec -it "$CONTAINER_ID" psql -U postgres -d pain_db -c "SELECT * FROM DummyPain LIMIT '$LIMIT';"
        exit 0

    elif [ $1 == "--reset" ]; then
        echo "Resetting database..."
        docker exec -it "$CONTAINER_ID" psql -U postgres -d pain_db -c "DROP TABLE IF EXISTS DummyPain;"
        exit 0
    fi
fi

# If no valid argument is provided, print usage
echo "Usage: ./populate-db.sh [--init] [--fill] [--test] [--reset]"
echo "  --init  : Initialize database schema (run once)"
echo "  --fill  : Fill database with dummy data (run after init)"
echo "  --test  : Test database connection and contents"
echo "  --reset : Reset database by dropping the DummyPain table"
exit 1
