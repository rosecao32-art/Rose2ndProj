#!/bin/bash

# Clean a CSV file by removing empty lines and trimming whitespace
INPUT_FILE="$1"
OUTPUT_FILE="$2"

if [ -z "$INPUT_FILE" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: ./clean_csv.sh input.csv output.csv"
    exit 1
fi

echo "Cleaning $INPUT_FILE..."

# Remove blank lines and trim spaces
sed '/^$/d; s/ *//g' "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Cleaned file saved to $OUTPUT_FILE"
