#!/usr/bin/env bash

set -euo pipefail

# Usage:
#   ./export-container-logs.sh [service] [output-directory]
#
# Example:
#   ./export-container-logs.sh server /var/backups/my-project/logs

CUR_DIR="${PWD}"
cd ..
echo "Changed workdir to ${PWD}"

SERVICE="${1:-pain-server}"
OUTPUT_DIR="${2:-./log-archive}"

# ------------------------------------------------------------
# Find the current container
# ------------------------------------------------------------

CONTAINER_ID="$(docker compose ps -q "$SERVICE")"

if [[ -z "$CONTAINER_ID" ]]; then
    echo "Error: no container found for Compose service '$SERVICE'." >&2
    exit 1
fi

# ------------------------------------------------------------
# Container metadata
# ------------------------------------------------------------

CONTAINER_NAME="$(
    docker inspect \
        --format='{{.Name}}' \
        "$CONTAINER_ID" |
    sed 's#^/##'
)"

CREATED_AT="$(
    docker inspect \
        --format='{{.Created}}' \
        "$CONTAINER_ID"
)"

# Convert creation timestamp to a filename-safe format.
CREATED_SAFE="$(
    date -d "$CREATED_AT" '+%Y-%m-%dT%H-%M-%SZ'
)"

SHORT_ID="${CONTAINER_ID:0:12}"

mkdir -p "$OUTPUT_DIR"

BASE_NAME="${SERVICE}-${CREATED_SAFE}-${SHORT_ID}"

LOG_OUTPUT="$OUTPUT_DIR/${BASE_NAME}.log"

# Start with empty files.
: > "$LOG_OUTPUT"

# ------------------------------------------------------------
# Export
#
# Pino writes one JSON object per line.
#
# Valid JSON objects are written to the .jsonl file.
# Everything else is preserved in the .non-json.log file.
# ------------------------------------------------------------

echo "Exporting logs..."
echo "  Service:   $SERVICE"
echo "  Container: $CONTAINER_NAME"
echo "  ID:        $CONTAINER_ID"
echo "  Created:   $CREATED_AT"
echo "  Logs:      $LOG_OUTPUT"
echo

LOG_COUNT=0

while IFS= read -r line; do

    printf '%s\n' "$line" >> "$LOG_OUTPUT"
    LOG_COUNT=$((LOG_COUNT + 1))

done < <(docker logs "$CONTAINER_ID" 2>&1)

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

LOG_SIZE="$(du -h "$LOG_OUTPUT" | cut -f1)"

echo
echo "Export complete."
echo "  Log entries:   $LOG_COUNT ($LOG_SIZE)"

echo "Going back to ${CUR_DIR}"
cd ${CUR_DIR}
