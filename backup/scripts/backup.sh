#!/bin/bash

MCDATA="/mcdata"
BACKUP_DIR="/backups"
HASH_FILE="$BACKUP_DIR/last_world_hash.txt"
MD5_CURRENT="$BACKUP_DIR/current.md5"
MD5_LAST="$BACKUP_DIR/last.md5"
MD5_DIFF="$BACKUP_DIR/diff.log"

INTERVAL_MINUTES=360

mkdir -p "$BACKUP_DIR"

echo "✅ Backup daemon started, checking for changes every $INTERVAL_MINUTES minutes..."

while true; do
  DATE=$(date +"%Y-%m-%d_%H-%M")

  echo "[$DATE] 🔍 Calculating file checksums..."
  # Generate current checksum list for all files in world directory
  find "$MCDATA/world" -type f -exec md5sum {} + | sort > "$MD5_CURRENT"

  # If previous checksum exists, compare differences
  if [ -f "$MD5_LAST" ]; then
    echo "[$DATE] 🧾 Comparing checksums with previous backup..."
    diff -u "$MD5_LAST" "$MD5_CURRENT" > "$MD5_DIFF" || true

    if [ -s "$MD5_DIFF" ]; then
      echo "[$DATE] ⚠️ Detected changes in files:"
      grep -E '^\+|^\-' "$MD5_DIFF" | grep -vE '^\+\+\+|^\-\-\-' | sed 's/^/    /'
    else
      echo "[$DATE] ✅ No file-level changes detected."
    fi
  else
    echo "[$DATE] ⚠️ No previous checksum found. This is the first run."
  fi

  # Compute total hash for determining backup necessity
  NEW_HASH=$(cat "$MD5_CURRENT" | md5sum | awk '{print $1}')

  if [ ! -f "$HASH_FILE" ]; then
    echo "$NEW_HASH" > "$HASH_FILE"
    cp "$MD5_CURRENT" "$MD5_LAST"
    echo "[$DATE] [First Backup] Starting..."
  else
    LAST_HASH=$(cat "$HASH_FILE")
    if [ "$NEW_HASH" = "$LAST_HASH" ]; then
      echo "[$DATE] No changes detected, skipping backup."
      sleep ${INTERVAL_MINUTES}m
      continue
    else
      echo "$NEW_HASH" > "$HASH_FILE"
      cp "$MD5_CURRENT" "$MD5_LAST"
      echo "[$DATE] Changes detected, starting backup..."
    fi
  fi

  # Perform the backup
  tar -czf "$BACKUP_DIR/mc_backup_$DATE.tar.gz" \
    -C "$MCDATA" world world_nether world_the_end \
    server.properties ops.json whitelist.json banned-players.json

  echo "[$DATE] ✅ Backup completed"
  # Delete backups older than 30 days
  find "$BACKUP_DIR" -type f -mtime +30 -delete

  sleep ${INTERVAL_MINUTES}m
done
