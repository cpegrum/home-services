# Intro
This git repo will contain all the Configuration as Code used to setup the self hosted akunting (bookkeeping/accounting software) server

# Services
## Bookkeeping Server
Akaunting server
### Containers
This setup contains 3 different containers:
* akaunting: This container hosts the akaunting bookkeeping/accounting software. It is connected to the `akauntingnet`
* mariadb: This container hosts the mariadb used by the akaunting software. It is connected to the `akauntingnet`. Akaunting waits for its healthcheck to pass before starting, so the first start can take a minute.
* swag: This reverse proxy provides SSL certs for the akaunting frontend. It is connected to the `akauntingnet` network with ports `80` and `443` exposed to allow external use.

### Networks
* `akauntingnet`: `10.10.50.0/24` -> Internet enabled network

### Setup

* Copy the `db.env.template` and the `run.env.template` from the `secrets/bookkeeping-secrets` directory and rename without the `.template` ending: `db.env` and `run.env`.
* In `db.env` change the `MYSQL_PASSWORD` to a random string:  `openssl rand -hex 24`
* Copy this password to `run.env` and place it in `DB_PASSWORD`.
* In `run.env` also set the following variables:
    * `APP_URL`: Set to the URL you will be accessing Akaunting with, including `https://`. ex: `https://akaunting.me.ca`
    * `DB_PREFIX`: Set to a unique string of 3 letters followed by a underscore: ex: `akt_`
    * `COMPANY_NAME`: First company that will be used for Akaunting
    * `COMPANY_EMAIL`: Email for the company (can be fake won't be send anything)
    * `ADMIN_EMAIL`: Email which will be used as username for default admin
    * `ADMIN_PASSWORD`: Password for default admin, set to something strong: `openssl rand -hex 24`
* For the swag container, do the following:
    * Make sure the `DOMAIN` variable in the `.env` file is filled with your domain.

    * Make sure the `cloudflare.ini` file in `./secrets/reverse-proxy-secrets/` has the cloudflare API key to be able to get a SSL cert
* When starting the server fresh for the first time, make sure to set the `AKAUNTING_SETUP=true` env variable. This should only be set for the first run and does not need to be set for it afterwards!
* Start the docker containers: `AKAUNTING_SETUP=true docker compose -f docker-compose-bookkeeping.yaml up -d --build`
* Head to your domain in your browser and do the initial setup
    * Set language
    * Confirm DB settings (nothing should need to change as all is set via .env)
    * Confirm initial company name and your login that you will use
    * Enter your Akaunting API key (costs money at akaunting.com)

* The initial setup should now be complete. Now when you restart the container don't set the `AKAUNTING_SETUP` env and it will start fine: `docker compose -f docker-compose-bookkeeping.yaml up -d --build`


### Backing up
The Akaunting setup can be backed up by backing up the two docker volumes: `home-services_akaunting-data` and `home-services_akaunting-db`.

The backups contain the whole accounting database and the Akaunting `.env` (app key and DB password), so store them **outside this repo** and somewhere private. The commands below write to `~/backups`:

```bash
mkdir -p ~/backups && chmod 700 ~/backups
```

* This command will generate a tarred file backup of the `akaunting-data` volume:
```bash
docker run -it --rm -v home-services_akaunting-data:/backup -v ~/backups:/host alpine:latest tar -C /backup -czf /host/akaunting-data-backup-$(date +"%Y-%m-%d-%H%M").tar.gz .
```

* This command will generate a tarred file backup of the `akaunting-db` volume:
```bash
docker run -it --rm -v home-services_akaunting-db:/backup -v ~/backups:/host alpine:latest tar -C /backup -czf /host/akaunting-db-backup-$(date +"%Y-%m-%d-%H%M").tar.gz .
```

### Restoring
Assuming backups were created using the above method shown in [Backing up](#backing-up), they can be restored using:

* For `akaunting-data` volume:
```bash
docker run -it --rm -v home-services_akaunting-data:/backup -v ~/backups:/host alpine:latest tar -xzf /host/akaunting-data-backup-<timestamp>.tar.gz -C /backup
```

* For the `akaunting-db` volume:
```bash
docker run -it --rm -v home-services_akaunting-db:/backup -v ~/backups:/host alpine:latest tar -xzf /host/akaunting-db-backup-<timestamp>.tar.gz -C /backup
```