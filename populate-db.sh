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
    
    # parse input
    if [ $# -gt 1 ]; then
        CONFIG_FILE="$2"
    else
        CONFIG_FILE="$SCRIPT_DIR/db-config.env"
    fi
    # load config file
    if [ -f "$CONFIG_FILE" ]; then
        # source the config file to import variables into environment
        . "$CONFIG_FILE"
    else
        echo "Missing DB config: $CONFIG_FILE" >&2
        exit 1
    fi

    # Check which operation is requested
    if [ $1 == "--init" ]; then
        echo "Initializing database schema..."
        # initialize database schema based on config file
        docker exec -it "$CONTAINER_ID" psql -U postgres -d pain_db -c "CREATE TABLE $TABLE_NAME ($COL_ID SERIAL PRIMARY KEY, $COL_LAT FLOAT NOT NULL, $COL_LNG FLOAT NOT NULL, $COL_VALUE FLOAT, $COL_DATATYPE TEXT NOT NULL, $COL_PAINORIGIN TEXT);"
        exit 0

    elif [ $1 == "--fill" ]; then
        if [ $# -gt 2 ]; then
            CSV_FILE="$3"
        else
            CSV_FILE="$WORKSPACE_ROOT/pain/data/dummy/db_data.csv"
        fi
        DEST="/tmp/db_data.csv"

        echo "Filling database with dummy data..."
        docker cp "$CSV_FILE" "$CONTAINER_ID:$DEST"
        docker exec "$CONTAINER_ID" psql -U postgres -d pain_db -c "COPY $TABLE_NAME FROM '$DEST' CSV HEADER;"
        echo "Imported data from $CSV_FILE into $TABLE_NAME table"

        exit 0

    elif [ $1 == "--test" ]; then
        echo "Testing database connection and contents..."
        if [ $# -gt 2 ]; then
            LIMIT="$3"
        else
            LIMIT="7"
        fi
        docker exec -it "$CONTAINER_ID" psql -U postgres -d pain_db -c "SELECT * FROM $TABLE_NAME LIMIT '$LIMIT';"
        exit 0

    elif [ $1 == "--reset" ]; then
        echo "Resetting database..."
        docker exec -it "$CONTAINER_ID" psql -U postgres -d pain_db -c "DROP TABLE IF EXISTS $TABLE_NAME;"
        exit 0
    fi
fi

# If no valid argument is provided, print usage
echo "Usage: ./populate-db.sh [--init] [--fill] [--test] [--reset]"
echo "  --init  : Initialize database schema (run once)"
echo "  --fill  : Fill database with dummy data (run after init)"
echo "  --test  : Test database connection and contents"
echo "  --reset : Reset database by dropping the table"
exit 1
