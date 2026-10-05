#!/bin/bash

WATCH_DIR="/home/rose@mxrc.org/Documents/incoming_data"
CLEAN_DIR="/home/rose@mxrc.org/Documents/incoming_data/cleaned"
ARCHIVE_DIR="/home/rose@mxrc.org/Documents/incoming_data/archive"
LOGFILE="/home/rose@mxrc.org/Documents/incoming_data/ingest.log"
DB_NAME="pgrose_db"
TABLE_NAME="incoming_data"

mkdir -p "$WATCH_DIR" "$CLEAN_DIR" "$ARCHIVE_DIR"

echo "Starting auto-ingest monitor..."
echo "Watching directory: $WATCH_DIR"

validate_schema() {
    local csv_file="$1"
    local schema_file="$2"

    # Extract header from CSV
    IFS=',' read -r -a csv_cols < <(head -n 1 "$csv_file")

    # Read schema file
    mapfile -t schema_lines < "$schema_file"

    # Compare column count
    if [[ ${#csv_cols[@]} -ne ${#schema_lines[@]} ]]; then
        echo "Schema mismatch: column count differs"
        return 1
    fi

    # Compare column names
    for i in "${!schema_lines[@]}"; do
        expected_col="${schema_lines[$i]%%:*}"
        actual_col="${csv_cols[$i]}"

        if [[ "$expected_col" != "$actual_col" ]]; then
            echo "Schema mismatch: expected '$expected_col' but found '$actual_col'"
            return 1
        fi
    done

    echo "Schema validation passed"
    return 0
}

inotifywait -m -e create -e moved_to --format "%f" "$WATCH_DIR" | while read FILE
do
    # Prevent infinite loop
    if [[ "$FILE" == cleaned_* ]]; then
        continue
    fi

    if [[ "$FILE" == *.csv ]]; then
        TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
        INPUT="$WATCH_DIR/$FILE"
        CLEANED="$CLEAN_DIR/cleaned_$FILE"

        echo "[$TIMESTAMP] New file detected: $FILE" >> "$LOGFILE"

         # Validate schema
        if ! validate_schema "$INPUT" "/home/rose@mxrc.org/Documents/incoming_data/schema.conf"; then
            echo "[$TIMESTAMP] Schema validation FAILED for $FILE" >> "$LOGFILE"
            mv "$INPUT" "$ARCHIVE_DIR/failed_$FILE"
         continue
        fi

        echo "[$TIMESTAMP] Schema validation passed" >> "$LOGFILE"

        # Clean CSV
        sed '/^$/d; s/ *//g' "$INPUT" > "$CLEANED"
        echo "[$TIMESTAMP] Cleaned file: $CLEANED" >> "$LOGFILE"

        # Load into PostgreSQL
        psql -U pgrose -d "$DB_NAME" -c "\COPY $TABLE_NAME FROM '$CLEANED' CSV HEADER;"
        echo "[$TIMESTAMP] Loaded into table: $TABLE_NAME" >> "$LOGFILE"

        mv "$INPUT" "$ARCHIVE_DIR/"
        echo "[$TIMESTAMP] Archived $FILE" >> "$LOGFILE"
    fi
done
