#!/bin/bash

# Backup PostgreSQL database
DB_NAME="pgrose_db"
BACKUP_DIR=~/Documents/db_backups
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILE="$BACKUP_DIR/${DB_NAME}_$TIMESTAMP.sql"

mkdir -p "$BACKUP_DIR"

echo "Backing up database $DB_NAME to $FILE..."

if pg_dump -U pgrose "$DB_NAME" > "$FILE"; then
    echo "Backup complete."
else
    echo "Backup FAILED."
fi
