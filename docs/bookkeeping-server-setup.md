# Intro
This git repo will contain all the Configuration as Code used to setup the self hosted akunting (bookkeeping/accounting software) server

# Services
## AI Server
Akaunting server
### Containers
This setup contains 3 different containers:
* akaunting: This container hosts the akaunting bookkeeping/accounting software. It is connected to the `akauntingnet`
* mariadb: This container hosts the mariadb used by the akaunting software. It is connected to the `akauntingnet`
* swag: This reverse proxy provides SSL certs for the akaunting frontend. It is connected to the `akauntingnet` network with ports `80` and `443` exposed to allow external use.

### Networks
* `akauntingnet`: `10.10.50.0/24` -> Internet enabled network

### Setup

* Copy the `db.env.template` and the `run.env.template` from the `secrets/bookkeeping-secrets` directory and rename without the `.template` ending: `db.env` and `run.env`.
* In `db.env` change the `MYSQL_PASSWORD` to a random string:  `openssl rand -base64 24`
* Copy this password to `run.env` and place it in `DB_PASSWORD`.
* In `run.env` also set the following variables:
    * `APP_URL`: Set to domain you will be accessing Akaunting with. ex: `akaunting.me.ca`
    * `DB_PREFIX`: Set to a unique string of 3 letters followed by a underscore: ex: `akt_`
    * `COMPANY_NAME`: First company that will be used for Akaunting
    * `COMPANY_EMAIL`: Email for the company (can be fake won't be send anything)
    * `ADMIN_EMAIL`: Email which will be used as username for default admin
    * `ADMIN_PASSWORD`: Password for default admin, set to something strong: `openssl rand -base64 24`
* For the swag container, do the following:
    * Make sure the `DOMAIN` variable in the `.env` file is filled with your domain.

    * Make sure the `cloudflare.ini` file in `./secrets/` has the cloudflare API key to be able to get a SSL cert
* When starting the server fresh for the first time, make sure to set the `AKAUNTING_SETUP=true` env variable. This should only be set for the first run and does not need to be set for it afterwards!
* Start the docker containers: `AKAUNTING_SETUP=true docker compose -f docker-compose-bookkeeping.yaml up -d --build`
* Head to your domain in your browser and do the initial setup
    * Set language
    * Confirm DB settings (nothing should need to change as all is set via .env)
    * Confirm initial company name and your login that you will use
    * Enter your Akaunting API key (costs money at akaunting.com)

* The initial setup should now be complete. Now when you restart the container don't set the `AKAUNTING_SETUP` env and it will start fine: `docker compose -f docker-compose-bookkeeping.yaml up -d --build`


### Backing up
The Akaunting setup and be backed up by backing up the two docker volumes: `akaunting-data` and `akaunting-db`

* This command will generate a tarred file backup of the `akaunting-data` volume:
```bash
docker run -it --rm -v home-services_akaunting-data:/backup -v $(pwd):/host alpine:latest tar -czf /host/akaunting-data-backup-$(date +"%Y-%m-%d-%H%M").tar.gz /backup
```

* This command will generate a tarred file backup of the `akaunting-db` volume:
```bash
docker run -it --rm -v home-services_akaunting-db:/backup -v $(pwd):/host alpine:latest tar -czf /host/akaunting-db-backup-$(date +"%Y-%m-%d-%H%M").tar.gz /backup
```

### Restoring
Assuming backups were created using the above method shown in [Backing up](#backing-up), they can be restored using:

* For `akaunting-data` volume:
```bash
docker run -it --rm -v home-services_akaunting-data:/backup -v $(pwd):/host alpine:latest tar -xzf /host/akaunting-data-backup-<timestamp>.tar.gz -C /backup
```

* For the `akaunting-db` volume:
```bash
docker run -it --rm -v home-services_akaunting-db:/backup -v $(pwd):/host alpine:latest tar -xzf /host/akaunting-db-backup-<timestamp>.tar.gz -C /backup
```