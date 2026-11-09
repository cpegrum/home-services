#!/bin/bash
# Encrypted backup of the Plex config (database, settings, artwork) and the repo's .env.
# See docs/plex-backup.md for setup, scheduling and restoring.
#
# Settings are read from the repo's .env:
#   PLEX_BACKUP_DEST        (required) folder to write backups to, ideally a NAS/SMB share
#   PLEX_BACKUP_AGE_KEY     (required) age public key (age1...), only able to encrypt
#   PLEX_BACKUP_MOUNT       (optional) mount point that must be mounted before backing up, ex: /mnt/plex-main
#   PLEX_BACKUP_KEEP_DAYS   (optional) delete backups older than this many days, default 56
#   PLEX_BACKUP_INCLUDE_MEDIA (optional) true to also back up video preview thumbnails (large), default false
#
# Must run as root (some Plex files are only readable by the Plex user).
set -euo pipefail
umask 077

REPO="${HOME_SERVICES_DIR:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}"
ENV_FILE="$REPO/.env"
COMPOSE=(docker compose -f "$REPO/docker-compose-plex.yaml")
CONFIG_DIR="$REPO/temp-data/plex-config"

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
[[ -d "$CONFIG_DIR" ]] || die "$CONFIG_DIR not found"

DEST=$(env_get PLEX_BACKUP_DEST)
AGE_KEY=$(env_get PLEX_BACKUP_AGE_KEY)
MOUNT=$(env_get PLEX_BACKUP_MOUNT)
KEEP_DAYS=$(env_get PLEX_BACKUP_KEEP_DAYS); KEEP_DAYS=${KEEP_DAYS:-56}
INCLUDE_MEDIA=$(env_get PLEX_BACKUP_INCLUDE_MEDIA)

[[ -n "$DEST" ]] || die "PLEX_BACKUP_DEST is not set in .env"
[[ "$AGE_KEY" == age1* ]] || die "PLEX_BACKUP_AGE_KEY is not set to an age public key (age1...) in .env"
[[ "$KEEP_DAYS" =~ ^[0-9]+$ ]] || die "PLEX_BACKUP_KEEP_DAYS must be a number"

# If the share isn't mounted we'd silently write into the empty mount folder on the local disk
if [[ -n "$MOUNT" ]]; then
    mountpoint -q "$MOUNT" || die "$MOUNT is not mounted, skipping backup"
fi
mkdir -p "$DEST"

EXCLUDES=(Cache Codecs Logs "Crash Reports" Updates Diagnostics Drivers)
[[ "$INCLUDE_MEDIA" == "true" ]] || EXCLUDES+=(Media)
TAR_EXCLUDES=()
for e in "${EXCLUDES[@]}"; do TAR_EXCLUDES+=("--exclude=Plex Media Server/$e"); done

STAMP=$(date +%F-%H%M)
OUT="$DEST/plex-config-$STAMP.tgz.age"

# Stop Plex so the SQLite database is consistent, and only start it again if it was running.
# The EXIT trap also runs on errors, so Plex is always restarted and partial files removed.
WAS_RUNNING=$("${COMPOSE[@]}" ps --status running -q plex)
cleanup() {
    rm -f "$OUT.tmp"
    if [[ -n "$WAS_RUNNING" ]]; then log "starting plex"; "${COMPOSE[@]}" start plex; fi
}
trap cleanup EXIT
if [[ -n "$WAS_RUNNING" ]]; then
    log "stopping plex"
    "${COMPOSE[@]}" stop plex
fi

log "backing up $CONFIG_DIR to $OUT"
# Write to a .tmp file and rename, so a failed run never leaves a half-written backup
tar -czf - -C "$CONFIG_DIR" "${TAR_EXCLUDES[@]}" . | age -r "$AGE_KEY" > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
age -r "$AGE_KEY" -o "$DEST/env-$STAMP.age" "$ENV_FILE"

log "removing backups older than $KEEP_DAYS days"
find "$DEST" -maxdepth 1 \( -name 'plex-config-*.tgz.age' -o -name 'env-*.age' \) -mtime +"$KEEP_DAYS" -print -delete

log "done: $(du -h "$OUT" | cut -f1) $OUT"
