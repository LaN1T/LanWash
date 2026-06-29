#!/usr/bin/env bash
set -euo pipefail

# LanWash PostgreSQL backup script.
# Run nightly via cron, e.g.:
#   0 3 * * * /path/to/LanWash/scripts/backup_postgres.sh >> /var/log/lanwash-backup.log 2>&1
#
# Required environment variables (read from the current shell or a .env file):
#   POSTGRES_USER
#   POSTGRES_DB
#   BACKUP_DIR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load variables from project .env if present and not already set.
if [ -f "${PROJECT_DIR}/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${PROJECT_DIR}/.env"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-lanwash_user}"
POSTGRES_DB="${POSTGRES_DB:-lanwash_db}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
CONTAINER_NAME="${CONTAINER_NAME:-lanwash_postgres}"

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/lanwash_db_${DATE}.sql.gz"

mkdir -p "${BACKUP_DIR}"

if docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  docker exec "${CONTAINER_NAME}" pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" \
    | gzip > "${BACKUP_FILE}"
else
  echo "ERROR: Container ${CONTAINER_NAME} is not running" >&2
  exit 1
fi

# Remove backups older than RETENTION_DAYS
find "${BACKUP_DIR}" -name 'lanwash_db_*.sql.gz' -type f -mtime +"${RETENTION_DAYS}" -delete

echo "Backup created: ${BACKUP_FILE}"
