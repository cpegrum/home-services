# Home Server Docker Setup
This Repo contains my home server docker setup and currently has the following services:

* Usenet Downloader via Sabnzbd with Sonarr with SWAG reverse proxy
* Tdarr setup for trancoding via CPU with SWAG reverse proxy


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