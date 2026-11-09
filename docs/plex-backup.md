# Plex Backups
`scripts/plex-backup.sh` makes an encrypted backup of the Plex config (database, watch history, settings, server identity and artwork) and of the repo's `.env`. Backups are encrypted with [age](https://github.com/FiloSottile/age), so people with access to the backup location (e.g. other users of the SMB share) can't read them.

The SWAG config is not backed up, as a new cert can always be requested.

## What gets backed up
From `temp-data/plex-config/Library/Application Support/Plex Media Server/`:

| Folder / file | Backed up | Why |
|---|---|---|
| `Preferences.xml` | Yes | Server identity and claim, without it Plex comes back as a new server |
| `Plug-in Support/Databases` | Yes | Libraries, watch history, users, settings |
| `Metadata` | Yes | Posters and artwork (custom ones are lost without it) |
| `Media` | Only with `PLEX_BACKUP_INCLUDE_MEDIA=true` | Video preview thumbnails, often the largest folder. Plex can regenerate them, but it takes a long time |
| `Cache`, `Codecs`, `Logs`, `Crash Reports`, `Updates`, `Diagnostics`, `Drivers` | No | Rebuilt automatically |

Plex is stopped for the few minutes the backup takes, so the SQLite database is copied in a consistent state. It is only started again if it was running before, and it is always restarted, even if the backup fails.

## Setup
### 1. Install age and create a key
```bash
sudo apt install age
```
```bash
age-keygen -o ~/plex-backup.key
```
This prints `Public key: age1...`, copy it for step 2.

The **private key** (the whole contents of `~/plex-backup.key`) is needed to restore. Save it somewhere off the server, e.g. in 1Password, then remove it from the server:
```bash
cat ~/plex-backup.key
```
```bash
shred -u ~/plex-backup.key
```
> ⚠️ If the private key is lost, the backups can't be decrypted. Don't keep the only copy on the server or the backup share.

The public key in `.env` can only encrypt, so it doesn't matter if someone reads it.

### 2. Configure `.env`
```
PLEX_BACKUP_DEST=/mnt/plex-main/backups
PLEX_BACKUP_AGE_KEY=age1...
PLEX_BACKUP_MOUNT=/mnt/plex-main
```
* `PLEX_BACKUP_DEST`: where backups are written. Ideally a NAS / SMB share, so the backups survive the server's disk dying.
* `PLEX_BACKUP_AGE_KEY`: the public key from step 1.
* `PLEX_BACKUP_MOUNT` (optional, recommended for network shares): the script refuses to run if this isn't mounted. Otherwise, if the share isn't mounted, the backup would silently be written into the empty mount folder on the local disk.
* `PLEX_BACKUP_KEEP_DAYS` (optional, default `56`): backups older than this are deleted.
* `PLEX_BACKUP_INCLUDE_MEDIA` (optional, default `false`): set to `true` to also back up video preview thumbnails.

### 3. SMB share notes
Make sure the share is mounted at boot, e.g. in `/etc/fstab`:
```
//nas/plex-main  /mnt/plex-main  cifs  credentials=/root/.smbcredentials,uid=1000,gid=1000,_netdev,nofail,x-systemd.automount  0  0
```
* `_netdev,nofail` stop the boot hanging if the NAS is down, `x-systemd.automount` mounts it on first use.
* The credentials file should be `chmod 600` and owned by root.
* SMB doesn't keep Linux file ownership, which is fine: `tar` stores ownership inside the archive and restores it.
* "Permission denied" when writing usually means the share user (from the credentials file) can't write to the folder on the NAS.

### 4. Test a backup and a restore
```bash
sudo ~/home-services/scripts/plex-backup.sh && ls -lh /mnt/plex-main/backups
```
Then check the backup can actually be decrypted (paste the private key into a temporary file):
```bash
nano /tmp/plex-backup.key
```
```bash
age -d -i /tmp/plex-backup.key "$(ls -t /mnt/plex-main/backups/plex-config-*.tgz.age | head -1)" | tar -tzf - | grep Preferences.xml
```
```bash
shred -u /tmp/plex-backup.key
```

### 5. Schedule it
Add to root's crontab (`sudo crontab -e`), e.g. every Sunday at 4:30am:
```
30 4 * * 0 /home/dev/home-services/scripts/plex-backup.sh >> /var/log/plex-backup.log 2>&1
```
The script runs as root because some Plex files are only readable by the Plex user.

> Note: root runs this script from the repo folder, so anyone who can edit the repo can run commands as root. If that matters, copy it somewhere only root can write and point it at the repo: `sudo install -m 700 scripts/plex-backup.sh /usr/local/bin/plex-backup.sh`, then use `HOME_SERVICES_DIR=/home/dev/home-services /usr/local/bin/plex-backup.sh` in the cron line (remember to re-copy it when the script changes).

Also leave Plex's own database backups on (Settings -> Scheduled Tasks -> "Backup database every three days"). They're a quick undo for database corruption, but they're stored in the same folder, so they don't replace this off-machine backup.

## Restoring
Paste the private key into `/tmp/plex-backup.key` first, then:
```bash
cd ~/home-services && docker compose -f docker-compose-plex.yaml stop plex
```
```bash
age -d -i /tmp/plex-backup.key /mnt/plex-main/backups/plex-config-<date>.tgz.age | sudo tar -xzpf - -C temp-data/plex-config
```
```bash
docker compose -f docker-compose-plex.yaml start plex
```
```bash
shred -u /tmp/plex-backup.key
```

On a new machine: clone the repo, restore `.env` (`age -d -i /tmp/plex-backup.key -o .env /mnt/plex-main/backups/env-<date>.age`), add `secrets/reverse-proxy-secrets/cloudflare.ini`, `mkdir -p temp-data/plex-config`, extract the backup as above, then `docker compose -f docker-compose-plex.yaml up -d`. No Plex claim token is needed, the restored server keeps its identity.
