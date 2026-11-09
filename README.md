# Home Server Docker Setup
This Repo contains my home server docker setup and currently has the following services:

* Usenet Downloader via Sabnzbd with Sonarr with SWAG reverse proxy
* Tdarr setup for trancoding via CPU with SWAG reverse proxy
* Ollama and Open WebUI AI server with SWAG reverse proxy
* Plex media server with SWAG reverse proxy
* Crowdsec + Swag reverse proxy


## General Setup
Each `docker-compose-*.yaml` file is its own stack with its own project name (`bookkeeping`, `dmz-ai`, `dmz-media`, `plex`, `proxy-waf`), so always pass the file: `docker compose -f docker-compose-<stack>.yaml up -d`.

Every stack has its own SWAG container (`swag-<stack>`) that publishes ports `80` and `443`, so **only run one stack per host** (or merge the proxy confs into a single SWAG).

> **Upgrading from before stacks had their own project names:** the stacks used to all share the `home-services` project. Before starting a stack with the new files, stop the old containers with `docker compose -p home-services -f docker-compose-<stack>.yaml down` (do **not** add `-v`). Data in `./temp-data` and the Akaunting volumes (`home-services_akaunting-*`, whose names are pinned) is kept.

Copy the `.env.template` file in the root of the repo and fill in the environment variables for
the location of your mounted share for media to be placed on. As well, include the URL of the domain that SWAG should serve.

### Usenet Downloader + Sonarr
This setup is done via the `docker-compose-dmz-media.yaml` file located in the root of this repo. It contains the following containers:

* Sabnzbd: Media Downloader from Usenet
* Sonarr: TV Show organizer and will download missing edpisodes via Sabnzbd
* SWAG: reverse proxy which will allow access to the Sonarr and Sanbzbd web UIs via `sonarr.<your domain>` and `sabnzbd.<your domain>` subdomains.
* Tdarr: Transcode Media with CPU
* wireguard: VPN to forward all traffic coming from Sonarr and Sabnzbd
* bind9: povides DNS for Sabnzbd and Sonarr containers.

To see more information on how to set this up check out the documentation [here](./docs/dmz-media-downloader.md)

### AI Server
This setup is done via the `docker-compose-dmz-ai.yaml` file located in the root of this repo. It contains the following containers:

* Ollama: This container hosts and runs the AI models.
* Open-Webui: This container hosts the Web frontend that allows for easy use of the AI models run by Ollama.
* swag: This reverse proxy provides SSL certs for the Open-Webui frontend.

### Plex
This setup is done via the `docker-compose-plex.yaml` file located in the root of this repo. It contains the following containers:

* Plex: Plex Media Server (with optional Intel hardware transcoding via `/dev/dri`).
* SWAG: reverse proxy which provides TLS for Plex via `plex.<your domain>`.

To see more information on how to set this up check out the documentation [here](./docs/plex-setup.md). Encrypted backups are covered [here](./docs/plex-backup.md).

### Crowdsec + Swag
This setup is done via the `docker-compose-proxy-waf.yaml` file located in the root of this repo. it container the following containers:

* Crowdsec: WAF engine that detects and protects a Swag instance.
* Swag: A Reverse Proxy to provides SSL certification as well as asks Crowdsec if it should block access to applications.

