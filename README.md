# Home Server Docker Setup
This Repo contains my home server docker setup and currently has the following services:

* Usenet Downloader via Sabnzbd with Sonarr with SWAG reverse proxy
* Tdarr setup for trancoding via CPU with SWAG reverse proxy
* Ollama and Open WebUI AI server with SWAG reverse proxy
* Crowdsec + Swag reverse proxy


## General Setup
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

### Crowdsec + Swag
This setup is done via the `docker-compose-proxy-waf.yaml` file located in the root of this repo. it container the following containers:

* Crowdsec: WAF engine that detects and protects a Swag instance.
* Swag: A Reverse Proxy to provides SSL certification as well as asks Crowdsec if it should block access to applications.

