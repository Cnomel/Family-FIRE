#!/bin/bash
# Family Fire - Database Backup Script
# Usage: ./scripts/backup.sh [backup_dir]

set -e

BACKUP_DIR="${1:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/family_fire_${TIMESTAMP}.sql"

mkdir -p "$BACKUP_DIR"

echo "Backing up database to ${BACKUP_FILE}..."

docker exec family-fire-db pg_dump -U postgres family_fire > "$BACKUP_FILE"

# Compress
gzip "$BACKUP_FILE"

echo "Backup complete: ${BACKUP_FILE}.gz"

# Keep only last 7 backups
ls -t "${BACKUP_DIR}"/family_fire_*.sql.gz | tail -n +8 | xargs -r rm

echo "Old backups cleaned (keeping last 7)"
