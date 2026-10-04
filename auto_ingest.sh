#!/bin/bash

WATCH_DIR=~/Documents/incoming_data
ARCHIVE_DIR=~/Documents/incoming_data/archive
LOGFILE=~/Documents/incoming_data/ingest.log
DB_NAME="pgrose_db"
TABLE_NAME="incoming_data"

mkdir -p "$WATCH_DIR" "$ARCHIVE_DIR"

echo "Starting auto-ingest monitor..."
echo "Watching directory: $WATCH_DIR"

inotifywait -m -e create --format "%f" "$WATCH_DIR" | while read FILE
do
    if [[ "$FILE" == *.csv ]]; then
        TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
        INPUT="$WATCH_DIR/$FILE"
        CLEANED="$WATCH_DIR/cleaned_$FILE"

        echo "[$TIMESTAMP] New file detected: $FILE" >> "$LOGFILE"

        # Clean CSV (remove blank lines + trim spaces)
        sed '/^$/d; s/ *//g' "$INPUT" > "$CLEANED"

        echo "[$TIMESTAMP] Cleaned file: $CLEANED" >> "$LOGFILE"

        # Load into PostgreSQL
        psql "$DB_NAME" -c "\COPY $TABLE_NAME FROM '$CLEANED' CSV HEADER;"
        echo "[$TIMESTAMP] Loaded into table: $TABLE_NAME" >> "$LOGFILE"

        # Move original file to archive
        mv "$INPUT" "$ARCHIVE_DIR/"
        mv "$CLEANED" "$ARCHIVE_DIR/"
        echo "[$TIMESTAMP] Archived $FILE" >> "$LOGFILE"
    fi
done
