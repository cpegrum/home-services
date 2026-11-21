# Akaunting Backups
`scripts/akaunting-backup.sh` makes an encrypted backup of the bookkeeping server and writes it to a backup folder, ideally an SMB share on a NAS. Backups are encrypted with [age](https://github.com/FiloSottile/age), so others with access to the share can't read them.

Each run creates one file, `akaunting-<date>-<time>.tar.age`, which contains:

| File inside | What it is |
|---|---|
| `akaunting-db.sql.gz` | A dump of the Akaunting database, made with `mariadb-dump --single-transaction` while MariaDB keeps running (no downtime) |
| `akaunting-data.tgz` | The `home-services_akaunting-data` volume: the Akaunting app files, uploaded attachments and Akaunting's own `.env` (including its `APP_KEY`) |
| `config.tgz` | This repo's `.env` and `secrets/bookkeeping-secrets/db.env` + `run.env` |

The SWAG config is not backed up, a new cert can always be requested.

> A database dump is used rather than copying the `akaunting-db` volume, because it is consistent without stopping MariaDB and can be restored into a newer MariaDB version.

## Setup
### 1. Install age and get a key
```bash
sudo apt install age
```
You can reuse the same key as the [Plex backups](./plex-backup.md) (just use the same public key below), or make a separate one:
```bash
age-keygen -o ~/akaunting-backup.key
```
This prints `Public key: age1...`. Save the whole contents of the key file somewhere off the server (e.g. 1Password), then remove it from the server:
```bash
cat ~/akaunting-backup.key
```
```bash
shred -u ~/akaunting-backup.key
```
> ⚠️ If the private key is lost, the backups can't be decrypted. Don't keep the only copy on the server or the backup share.

### 2. Configure `.env`
```
AKAUNTING_BACKUP_DEST=/mnt/backups/akaunting
AKAUNTING_BACKUP_AGE_KEY=age1...
AKAUNTING_BACKUP_MOUNT=/mnt/backups
```
* `AKAUNTING_BACKUP_DEST`: where backups are written.
* `AKAUNTING_BACKUP_AGE_KEY`: the public key from step 1 (it can only encrypt, so it is fine for it to be readable).
* `AKAUNTING_BACKUP_MOUNT` (optional, recommended for network shares): the script refuses to run if this isn't mounted, so it never silently writes backups to the local disk when the share is down.
* `AKAUNTING_BACKUP_KEEP_DAYS` (optional, default `30`): backups older than this are deleted.

### 3. Mount the SMB share
Mount the share on the bookkeeping server at boot, e.g. in `/etc/fstab`:
```
//nas/backups  /mnt/backups  cifs  credentials=/root/.smbcredentials,uid=1000,gid=1000,_netdev,nofail,x-systemd.automount  0  0
```
* `_netdev,nofail` stop the boot hanging if the NAS is down, `x-systemd.automount` mounts it on first use.
* The credentials file should be `chmod 600` and owned by root.
* "Permission denied" when writing usually means the share user (from the credentials file) can't write to the folder on the NAS.

### 4. Test a backup
```bash
sudo ~/home-services/scripts/akaunting-backup.sh && ls -lh /mnt/backups/akaunting
```
Then check it decrypts and the database dump is complete (paste the private key into a temporary file first):
```bash
nano /tmp/akaunting-backup.key
```
```bash
mkdir -p /tmp/akaunting-restore && age -d -i /tmp/akaunting-backup.key "$(ls -t /mnt/backups/akaunting/akaunting-*.tar.age | head -1)" | tar -xf - -C /tmp/akaunting-restore && ls -lh /tmp/akaunting-restore
```
```bash
zcat /tmp/akaunting-restore/akaunting-db.sql.gz | tail -n 1
```
The last command should print `-- Dump completed on <date>`. Then clean up:
```bash
rm -rf /tmp/akaunting-restore && shred -u /tmp/akaunting-backup.key
```

### 5. Schedule it
Accounting data changes often, so a daily backup is a good default. Add to root's crontab (`sudo crontab -e`), e.g. every night at 2:15am:
```
15 2 * * * /home/dev/home-services/scripts/akaunting-backup.sh >> /var/log/akaunting-backup.log 2>&1
```
> Note: root runs this script from the repo folder, so anyone who can edit the repo can run commands as root. If that matters, copy it somewhere only root can write: `sudo install -m 700 scripts/akaunting-backup.sh /usr/local/bin/akaunting-backup.sh`, and use `HOME_SERVICES_DIR=/home/dev/home-services /usr/local/bin/akaunting-backup.sh` in the cron line (re-copy it when the script changes).

## Restoring
Paste the private key into `/tmp/akaunting-backup.key`, then decrypt the backup you want:
```bash
mkdir -p /tmp/akaunting-restore && age -d -i /tmp/akaunting-backup.key /mnt/backups/akaunting/akaunting-<date>-<time>.tar.age | tar -xf - -C /tmp/akaunting-restore
```

### On the same server
Stop Akaunting so nothing writes to the database while it is restored (MariaDB keeps running):
```bash
cd ~/home-services && docker compose -f docker-compose-bookkeeping.yaml stop akaunting
```
Restore the database. The dump drops and recreates each table, so this replaces the current data:
```bash
zcat /tmp/akaunting-restore/akaunting-db.sql.gz | docker exec -i mariadb sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mariadb -u "$MYSQL_USER" "$MYSQL_DATABASE"'
```
Restore the app files and uploads (this overwrites files in the volume with the backed up copies):
```bash
docker run --rm -v home-services_akaunting-data:/data -v /tmp/akaunting-restore:/restore:ro alpine:latest tar -xzpf /restore/akaunting-data.tgz -C /data
```
```bash
docker compose -f docker-compose-bookkeeping.yaml start akaunting
```

### On a new server
1. Clone the repo and restore the config first: `tar -xzf /tmp/akaunting-restore/config.tgz -C ~/home-services` (puts back `.env` and the bookkeeping secrets, so the database password matches the backup). Add `secrets/reverse-proxy-secrets/cloudflare.ini`.
2. Start only MariaDB, which creates an empty database with the user from `db.env`: `docker compose -f docker-compose-bookkeeping.yaml up -d mariadb`
3. Restore the database and the app files with the two commands above.
4. Start everything: `docker compose -f docker-compose-bookkeeping.yaml up -d`. Don't set `AKAUNTING_SETUP`, the restored install is already set up.

Finally, clean up:
```bash
rm -rf /tmp/akaunting-restore && shred -u /tmp/akaunting-backup.key
```
