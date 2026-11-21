#!/bin/bash
# Encrypted backup of Akaunting: a dump of the MariaDB database, the akaunting-data volume
# (app files, uploads and Akaunting's own .env), and this repo's .env + bookkeeping secrets.
# See docs/akaunting-backup.md for setup, scheduling and restoring.
#
# Settings are read from the repo's .env:
#   AKAUNTING_BACKUP_DEST       (required) folder to write backups to, ideally a NAS/SMB share
#   AKAUNTING_BACKUP_AGE_KEY    (required) age public key (age1...), only able to encrypt
#   AKAUNTING_BACKUP_MOUNT      (optional) mount point that must be mounted before backing up, ex: /mnt/backups
#   AKAUNTING_BACKUP_KEEP_DAYS  (optional) delete backups older than this many days, default 30
#
# The database is dumped while it runs (mariadb-dump --single-transaction), so there is no downtime.
# Must run as root (reads the secrets files and talks to Docker).
set -euo pipefail
umask 077

REPO="${HOME_SERVICES_DIR:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}"
ENV_FILE="$REPO/.env"
DB_CONTAINER=mariadb
# Must match the volume names in docker-compose-bookkeeping.yaml
DATA_VOLUME=home-services_akaunting-data
SECRET_FILES=(secrets/bookkeeping-secrets/db.env secrets/bookkeeping-secrets/run.env)

log() { echo "$(date '+%F %T') $*"; }
die() { log "ERROR: $*" >&2; exit 1; }

# Read a single KEY=value from .env without sourcing it (strips surrounding quotes)
env_get() {
    local v
    v=$(grep -E "^$1=" "$ENV_FILE" | tail -n1 | cut -d= -f2-) || true
    v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
    printf '%s' "$v"
}

[[ $EUID -eq 0 ]] || die "must run as root (sudo)"
[[ -f "$ENV_FILE" ]] || die "$ENV_FILE not found (set HOME_SERVICES_DIR if the script was moved)"
command -v age >/dev/null || die "age is not installed (sudo apt install age)"
command -v docker >/dev/null || die "docker is not installed"

DEST=$(env_get AKAUNTING_BACKUP_DEST)
AGE_KEY=$(env_get AKAUNTING_BACKUP_AGE_KEY)
MOUNT=$(env_get AKAUNTING_BACKUP_MOUNT)
KEEP_DAYS=$(env_get AKAUNTING_BACKUP_KEEP_DAYS); KEEP_DAYS=${KEEP_DAYS:-30}

[[ -n "$DEST" ]] || die "AKAUNTING_BACKUP_DEST is not set in .env"
[[ "$AGE_KEY" == age1* ]] || die "AKAUNTING_BACKUP_AGE_KEY is not set to an age public key (age1...) in .env"
[[ "$KEEP_DAYS" =~ ^[0-9]+$ ]] || die "AKAUNTING_BACKUP_KEEP_DAYS must be a number"
[[ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER" 2>/dev/null)" == "true" ]] || die "$DB_CONTAINER container is not running"
docker volume inspect "$DATA_VOLUME" >/dev/null 2>&1 || die "docker volume $DATA_VOLUME not found"

# If the share isn't mounted we'd silently write into the empty mount folder on the local disk
if [[ -n "$MOUNT" ]]; then
    mountpoint -q "$MOUNT" || die "$MOUNT is not mounted, skipping backup"
fi
mkdir -p "$DEST"

STAMP=$(date +%F-%H%M)
OUT="$DEST/akaunting-$STAMP.tar.age"
# Plain-text pieces are staged in a private temp folder and removed on exit, even on errors
STAGE=$(mktemp -d)
cleanup() { rm -rf "$STAGE"; rm -f "$OUT.tmp"; }
trap cleanup EXIT

log "dumping database from $DB_CONTAINER"
# Credentials come from the container's own environment (db.env), and MYSQL_PWD keeps the
# password off the command line
docker exec "$DB_CONTAINER" sh -c '
    user="${MARIADB_USER:-$MYSQL_USER}"; db="${MARIADB_DATABASE:-$MYSQL_DATABASE}"
    MYSQL_PWD="${MARIADB_PASSWORD:-$MYSQL_PASSWORD}" exec mariadb-dump --single-transaction --quick --triggers -u "$user" "$db"
' | gzip > "$STAGE/akaunting-db.sql.gz"
# mariadb-dump writes this line last, so its absence means the dump was cut short
zcat "$STAGE/akaunting-db.sql.gz" | tail -n 1 | grep -q '^-- Dump completed' || die "database dump looks incomplete"

log "archiving volume $DATA_VOLUME"
docker run --rm -v "$DATA_VOLUME":/data:ro alpine:latest tar -czf - -C /data . > "$STAGE/akaunting-data.tgz"

log "archiving .env and bookkeeping secrets"
files=(.env)
for f in "${SECRET_FILES[@]}"; do [[ -f "$REPO/$f" ]] && files+=("$f"); done
tar -czf "$STAGE/config.tgz" -C "$REPO" "${files[@]}"

log "encrypting to $OUT"
# Write to a .tmp file and rename, so a failed run never leaves a half-written backup
tar -cf - -C "$STAGE" . | age -r "$AGE_KEY" > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"

log "removing backups older than $KEEP_DAYS days"
find "$DEST" -maxdepth 1 -name 'akaunting-*.tar.age' -mtime +"$KEEP_DAYS" -print -delete

log "done: $(du -h "$OUT" | cut -f1) $OUT"
