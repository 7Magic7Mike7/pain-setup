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
    # ############################################################
    #   INIT
    # ############################################################
    if [ $1 == "--init" ]; then
        create_table() {
            # $1... table name
            # $2... additional column information
            echo "  Creating table $1..."
            docker exec -it "$CONTAINER_ID" psql -U postgres -d pain_db -c "CREATE TABLE $1 ($COL_ID SERIAL PRIMARY KEY $2);"
        }
        create_data_table() {
            # $1... table name
            # $2... additional column information
            create_table $1 ", $COL_AGGR_ID INTEGER REFERENCES $1($COL_ID), $COL_VALUE FLOAT NOT NULL, $COL_CATEGORY TEXT NOT NULL $2"
        }
        create_metrics_table() {
            # $1... table name
            # $2... additional column information
            create_table $1 ", $COL_DT $TYPE_DT NOT NULL, $COL_USER_ID INTEGER REFERENCES $TNM_USERS($COL_ID) $2"
        }
        echo "Initializing database schema..."
        # initialize database schema based on config file
        # initialize tables for our data
        create_data_table $TN_EMO ", $COL_COUNTRY TEXT NOT NULL, $COL_WORD TEXT NOT NULL"
        create_data_table $TN_ENV ", $COL_LAT FLOAT NOT NULL, $COL_LNG FLOAT NOT NULL"
        create_data_table $TN_PHYS ", $COL_LAT FLOAT NOT NULL, $COL_LNG FLOAT NOT NULL"
        create_data_table $TN_SOCIOECO ", $COL_COUNTRY TEXT NOT NULL"
        create_data_table $TN_EXPERIMENTAL ", $COL_LAT FLOAT NOT NULL, $COL_LNG FLOAT NOT NULL"

        # initialize enums for metrics tables
        # CREATE TYPE $TYPE_CATEGORY AS ENUM ('person', 'color', 'activity', 'adjective', 'bigthing', 'smallthing');
        docker exec -it $CONTAINER_ID psql -U postgres -d pain_db -c "CREATE TYPE ${TYPE_TOGGLE_KIND} AS ENUM ('layer', 'word', 'temporality', 'relation', 'category');"
        # TODO: create enum type for element & vizMode
        #docker exec -it $CONTAINER_ID psql -U postgres -d pain_db -c "CREATE TYPE ${TYPE_TOGGLE_ELEM} AS STRING;"
        #docker exec -it $CONTAINER_ID psql -U postgres -d pain_db -c "CREATE TYPE ${TYPE_VIS_MODE} AS STRING;"
        # initialize tables for usage metrics
        create_table $TNM_USERS ", $COL_DT $TYPE_DT NOT NULL, $COL_USER_ID TEXT NOT NULL"
        create_metrics_table $TNM_TOGGLE ", $COL_KIND TEXT NOT NULL, $COL_ELEM TEXT NOT NULL, $COL_ENABLED BOOL NOT NULL"
        create_metrics_table $TNM_STEP ", $COL_STEP INTEGER NOT NULL"
        create_metrics_table $TNM_VIS ", $COL_VIS_MODE TEXT NOT NULL"
        exit 0

    # ############################################################
    #   FILL
    # ############################################################
    elif [ $1 == "--fill" ]; then
        fill_table() {
            #$1... table name
            #$2... source path
            #$3... destination path
            echo "Filling $1 with dummy data..."
            docker cp "$2" "$CONTAINER_ID:$3"
            # copy data from CSV into the table
            docker exec $CONTAINER_ID psql -U postgres -d pain_db -c "COPY $1 FROM '$3' CSV HEADER;"
            # reset the sequence for the table's serial ID column
            docker exec $CONTAINER_ID psql -U postgres -d pain_db -c "SELECT setval(pg_get_serial_sequence('$1', '$COL_ID'), COALESCE(MAX($COL_ID), 1)) FROM $1;"
            echo "  Imported data from $2 into $1 table"
        }

        if [ $# -gt 2 ]; then
            CSV_ROOT_FOLDER="$3"
        else
            CSV_ROOT_FOLDER="/tmp/data"
        fi
        echo "Filling database with dummy data..."
        fill_table $TN_EMO "${CSV_ROOT_FOLDER}/emo.csv" "/tmp/emo.csv"
        fill_table $TN_ENV "${CSV_ROOT_FOLDER}/env.csv" "/tmp/env.csv"
        fill_table $TN_PHYS "${CSV_ROOT_FOLDER}/phys.csv" "/tmp/phys.csv"
        fill_table $TN_SOCIOECO "${CSV_ROOT_FOLDER}/socioeco.csv" "/tmp/socioeco.csv"
        fill_table $TN_EXPERIMENTAL "${CSV_ROOT_FOLDER}/experimental.csv" "/tmp/experimental.csv"

        exit 0

    # ############################################################
    #   TEST
    # ############################################################
    elif [ $1 == "--test" ]; then
        echo "Testing database connection and contents..."
        if [ $# -gt 2 ]; then
            LIMIT="$3"
        else
            LIMIT="7"
        fi
        docker exec -it "$CONTAINER_ID" psql -U postgres -d pain_db -c "SELECT * FROM $TABLE_NAME LIMIT '$LIMIT';"
        exit 0
    elif [ $1 == "--connect" ]; then
        echo "Connecting to database..."
        docker exec -it $CONTAINER_ID psql -U postgres -d pain_db
    # ############################################################
    #   RESET
    # ############################################################
    elif [ $1 == "--reset" ]; then
        drop_table() {
            #$1... table name
            docker exec -it "$CONTAINER_ID" psql -U postgres -d pain_db -c "DROP TABLE IF EXISTS $1;"
        }
        echo "Resetting database..."
        drop_table $TN_EMO
        drop_table $TN_ENV
        drop_table $TN_PHYS
        drop_table $TN_SOCIOECO
        drop_table $TN_EXPERIMENTAL
        # todo drop types
        drop_table $TNM_TOGGLE
        drop_table $TNM_STEP
        drop_table $TNM_VIS
        drop_table $TNM_USERS
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
