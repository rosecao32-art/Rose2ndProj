#!/bin/bash

# Run Python ETL and log output with timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
LOGFILE="etl1_run.log"

echo "[$TIMESTAMP] Starting ETL..." >> "$LOGFILE"

python3 ~/Documents/RoseGitHub/Project2/PSQL_CSV_DB1.py >> "$LOGFILE" 2>&1

echo "[$TIMESTAMP] ETL completed." >> "$LOGFILE"
