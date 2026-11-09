# Intro
This git repo will contain all the Configuration as Code used to setup my Plex media server.

# Services
## Plex Server
Plex Media Server with a SWAG reverse proxy in front of it.
### Containers
This setup contains 2 different containers:
* plex: This container runs Plex Media Server. It is connected to the `plexnet` network and publishes port `32400` for direct (LAN) access.
* swag: This reverse proxy provides SSL certs for Plex and serves it on `plex.<your domain>`. It is connected to the `plexnet` network with ports `80` and `443` exposed to allow external use.

### Networks
* `plexnet`: `10.10.60.0/24` -> Internet enabled network

### Setup
* Copy the `.env.template` file in the root of the repo to `.env` and fill in:
    * `DOMAIN`: your domain, Plex will be served at `plex.<DOMAIN>`
    * `PLEX_MEDIA_PATH`: where your media library is mounted (it is mounted read-write into the container as `/data` so Plex can edit media, e.g. delete files or save posters/subtitles next to them)
    * `PLEX_TRANSCODE_PATH`: where Plex should write transcode files (use a local disk rather than a network share)
    * (Optional) `PLEX_UID` / `PLEX_GID`: user/group Plex runs as, these must be able to read and write the media path. Defaults to `1000`.

* Make sure the `cloudflare.ini` file in `./secrets/reverse-proxy-secrets/` has the cloudflare API key to be able to get a SSL cert.

* Optional: Hardware transcoding uses Intel Quick Sync through `/dev/dri`. If your machine doesn't have it, remove the `devices:` section from `docker-compose-plex.yaml`. Hardware transcoding also requires Plex Pass.

* Get a claim token from https://plex.tv/claim (it expires after about 4 minutes), then start the containers the first time with:
  `PLEX_CLAIM=claim-xxxxxxxx docker compose -f docker-compose-plex.yaml up -d`
    * The token is only needed the first time. For restarts use: `docker compose -f docker-compose-plex.yaml up -d`
    * Don't commit the claim token anywhere.

* Check the SWAG logs (`docker logs swag-plex`) to make sure a certificate was generated.

* In the Plex web UI go to Settings -> Network and fill in "Custom server access URLs" with `https://plex.<your domain>:443`. The container also sets `ADVERTISE_IP` to this.

### Using with the Crowdsec WAF proxy
`docker-compose-proxy-waf.yaml` can also front Plex. If you want to use it in front of this setup, you can't run both on the same host as both publish ports `80`/`443`. On the WAF host, set `upstream_app` in `proxy-waf-plex.subdomain.conf` to the IP of this server (port `443`, https), and keep this setup's SWAG as the backend.

### Notes
* `temp-data/plex-config` holds the Plex database and metadata, back it up.
* Port `32400` is published directly for LAN clients. Remove that port mapping if you want Plex only reachable via SWAG.
