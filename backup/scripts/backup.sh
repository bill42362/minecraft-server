#!/bin/bash

# Exit on error, undefined variable, or failed pipe
set -euo pipefail

# Trap for unexpected exits
trap 'echo "❌ Script exited unexpectedly. Check above logs for details." >&2' EXIT

MCDATA="/mcdata"
BACKUP_DIR="/backups"
WORLD_DIR="$MCDATA/world"
HASH_FILE="$BACKUP_DIR/last_world_hash.txt"
MD5_CURRENT="$BACKUP_DIR/current.md5"
MD5_LAST="$BACKUP_DIR/last.md5"
MD5_DIFF="$BACKUP_DIR/diff.log"
INTERVAL_MINUTES=360

# Validate tools
for tool in md5sum tar find diff awk sort grep sed; do
  command -v "$tool" >/dev/null 2>&1 || { echo "❌ Required command '$tool' not found."; exit 1; }
done

# Check world directory exists
if [ ! -d "$WORLD_DIR" ]; then
  echo "❌ World directory '$WORLD_DIR' does not exist."
  exit 1
fi

mkdir -p "$BACKUP_DIR"

echo "✅ Backup daemon started, checking for changes every $INTERVAL_MINUTES minutes..."

while true; do
  DATE=$(date +"%Y-%m-%d_%H-%M")

  echo "[$DATE] 🔍 Calculating file checksums..."
  find "$WORLD_DIR" -type f -exec md5sum {} + | sort > "$MD5_CURRENT"

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

  BACKUP_FILENAME="$BACKUP_DIR/mc_backup_$DATE.tar.gz"

  echo "[$DATE] 📦 Creating backup: $BACKUP_FILENAME"
  tar -czf "$BACKUP_FILENAME" \
    -C "$MCDATA" world world_nether world_the_end \
    server.properties ops.json whitelist.json banned-players.json \
    || { echo "❌ Backup failed during compression."; exit 1; }

  echo "[$DATE] ✅ Backup completed successfully."

  echo "[$DATE] 🧹 Cleaning up old backups (30+ days)..."
  find "$BACKUP_DIR" -type f -mtime +30 -delete || echo "⚠️ Cleanup failed, continuing."

  sleep ${INTERVAL_MINUTES}m
done
