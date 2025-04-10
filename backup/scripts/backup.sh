#!/bin/bash

MCDATA="/mcdata"
BACKUP_DIR="/backups"
HASH_FILE="$BACKUP_DIR/last_world_hash.txt"

INTERVAL_MINUTES=360

mkdir -p "$BACKUP_DIR"

echo "✅ Backup daemon started, checking for changes every $INTERVAL_MINUTES minutes..."

while true; do
  DATE=$(date +"%Y-%m-%d_%H-%M")
  NEW_HASH=$(find "$MCDATA/world" -type f -exec md5sum {} + | sort | md5sum | awk '{print $1}')

  if [ ! -f "$HASH_FILE" ]; then
    echo "$NEW_HASH" > "$HASH_FILE"
    echo "[First Backup] Starting..."
  else
    LAST_HASH=$(cat "$HASH_FILE")
    if [ "$NEW_HASH" = "$LAST_HASH" ]; then
      echo "[$DATE] No changes detected, skipping backup."
      sleep ${INTERVAL_MINUTES}m
      continue
    else
      echo "$NEW_HASH" > "$HASH_FILE"
      echo "[$DATE] Changes detected, starting backup..."
    fi
  fi

  tar -czf "$BACKUP_DIR/mc_backup_$DATE.tar.gz" \
    -C "$MCDATA" world world_nether world_the_end \
    server.properties ops.json whitelist.json banned-players.json

  echo "[$DATE] Backup completed ✅"
  find "$BACKUP_DIR" -type f -mtime +30 -delete

  sleep ${INTERVAL_MINUTES}m
done
