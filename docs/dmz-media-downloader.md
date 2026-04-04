# Intro
This git repo will contain all the Configuration as Code used to setup my home media server

# Services
## Media Downloader
Usenet based downloader with the following containers:
### Containers
 This setup contains 6 different containers:
 * Sabnzbd: This container hosts the Sabnzbd server which does the downloading of the files from usenet.
   * It is connected to the `vpnnet-internal` network, which does not have external network (internet) access.
* Sonarr: This container hosts the Sonarr server which monitors for new TV show episodes and downloads them via the Sabnzbd container.
   * It is connected to the `vpnnet-internal` network, which does not have any external network access. All outside requests are sent via the wireguard container.
* Radarr: This container hosts the Radarr server which monitors for new Movies and downloads them via the Sabnzbd container.
   * It is connected to the `vpnnet-internal` network, which does not have any external network access. All outside requests are sent via the wireguard container.
* wireguard: This container connects to Mullvad VPN and using the POSTUP and PREDOWN rules, will also forward on any traffic sent to this container to the VPN as well
    * It is connected to both the `vpnnet` which has internet access and `vpnnet-internal` which has no internet access
* swag: This container provides the SWAG proxy for the sabnzbd webui. It adds TLS and reverse proxies to sabnzbd located at port 8080 and the sonarr located at port 8989
    * It is connected to both the `vpnnet` which has internet access and `vpnnet-internal` which has no internet access. `vpnnet` is needed to get new certs from letsencrypt etc.
* bind9: This container is a DNS resolver and provides DNS support to the Sabnzbd container. Because the Sabnzbd container is located on an isolated network,
    it has no external network access. the Bind9 container provides DNS to the Sabnzbd container, which can then connect out to the internet via the wireguard container.
    * It is connected to the `vpnnet-internal` network. DNS requests are forwarded via the wireguard VPN container to public DNS servers. It is used by the sabnzbd and Sonarr.
* tdarr: This container reformats video files to reduce space used and remove unwanted audio tracks etc.
    * It is connected to `vpnnet` network so that it can download plugins etc.

### Networks
* `vpnnet`: `10.10.10.0/24` -> Internet enabled network 
* `vpnnet-internal`: `10.10.20.0/24` -> Internal access only network

### Setup
* Install docker and mount the plex-store-main

`sudo mount -t cifs -o user=usenet,gid=1000,uid=1000 //<Share domain> /mnt/<SMB-share-name>/`

* On the SMB share side, disabling SMB oplock can be helpful if you notice issues turning on and off the sonarr container (ex: it hangs)

* pull the required containers:

  * linuxserver:swag:latest
  * linuxserver/wireguard:latest
  * linuxserver/sabnzbd:latest
  * linuxserver/sonarr:latest
  * linuxserver/radarr:latest
  * internetsystemsconsortium/bind9:9.20

* go to mullvad and download a wireguard config: https://mullvad.net/en/account/wireguard-config

* Add the following lines for POSTUP and PREDOWN actions

```
PostUp = iptables -t nat -A POSTROUTING -o ca-mtr-wg-001 -j MASQUERADE
PreDown = iptables -t nat -D POSTROUTING -o ca-mtr-wg-001 -j MASQUERADE

```

* Make sure the name is the POSTUP and PREDOWN actions matches the name of the wireguard server you are connecting to
  for that you need to look at the endpoint name of the Mullvad server.

  It should look like this

    ```
    [Interface]
    # Device: Liked Shark
    PrivateKey = <key>
    Address = 10.64.55.244/32
    DNS = 104.242.2.3
    PostUp = iptables -t nat -A POSTROUTING -o ca-mtr-wg-001 -j MASQUERADE
    PreDown = iptables -t nat -D POSTROUTING -o ca-mtr-wg-001 -j MASQUERADE


    [Peer]
    PublicKey = <key>
    AllowedIPs = 0.0.0.0/0
    Endpoint = 178.249.214.15:51820

    ```

* create the folder wireguard-config in ./temp-data and place this config in ./temp-data/wireguard-config/

* start the docker containers

`docker compose up -f docker-compose-dmz-media.yaml -d --build`

* enter ./usenet-setup/sabnzbd-config/ and edit the  sabnzbd.ini file with the following

    ```
    host_whitelist = sabnzbd.<your domain>,sabnzbd # Comma separate different entries
    ```

* restart containers with docker compose

* check logs and swag-config/keys to make sure a certificate was generated

* Sabnzbd Setup

    * go to https://sabnzbd.<your domain>
        * For testing, you may need to add the domain into your `/etc/hosts` files for it to resolve properly, as SWAG needs you to go to the domain (not the IP) to properly redirect

    * complete the startup wizard
        * Enter Eweka creds
        * Move Temp downloads folder to /incomplete-downloads
        * Move Completed downloads to /downloads
        * Move Watched Folder to /watch-folder
        * General setting -> Set username and password to those in 1password

* Sonarr Setup
    * Go to https://sonarr.<your domain>
    * Configure authentication
        * Auth Method -> Forms (login page)
        * Choose Username and password
        * Save
    * Configure Media Management
        * Go to Settings -> Media Management
        * Click Show Advanced (top Left)
        * Enable Rename Episodes
        * Using Info from Trash guides: https://trash-guides.info/Sonarr/Sonarr-recommended-naming-scheme/
            * Standard Episode Format: `{Series TitleYear} - S{season:00}E{episode:00} - {Episode CleanTitle} [{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[MediaInfo VideoCodec]}{-Release Group}`
            * Daily Episode Format: `{Series TitleYear} - {Air-Date} - {Episode CleanTitle} [{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[MediaInfo VideoCodec]}{-Release Group}`
            * Anime Episode Format: `{Series TitleYear} - S{season:00}E{episode:00} - {absolute:000} - {Episode CleanTitle} [{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}[{MediaInfo VideoBitDepth}bit]{[MediaInfo VideoCodec]}[{Mediainfo AudioCodec} { Mediainfo AudioChannels}]{MediaInfo AudioLanguages}{-Release Group}`
            * Series Folder Format: `{Series TitleYear}`
            * Season Folder Format: `Season {season:00}`
            * Select Import Extra Files and make sure srt is added
            * Unselect use Hardlinks
            * Add the `/tv` folder as a root folder
            * Everything else as default and Save
    * Set Quality Setting
        * Go to Settings -> Quality
        * Show advanced and follow the defaults shown here: https://trash-guides.info/Sonarr/Sonarr-Quality-Settings-File-Size/
    * Configure Quality Profiles
        * Go to Settings -> Profiles
        * Make a 4K one with Blu-ray 2160 and 1080 and web 2160 and 1080
            * Upgrade until Web 2160
        * make a 1080p one with Blu-ray 1080 and 720 and Web 1080 and 720
            * Upgrade until Web 1080
    * Configure Indexers
        * Go to Settings -> Indexers
        * Add new -> newznab
            * name: NZBgeek
            * url: https://api.nzbgeek.info
            * API path: /api
            * API key: Get key from nzbgeek profile
            * Categories: make sure UHD is also selected for TV
    * Configure Download clients
        * Go to Settings -> Download Clients
        * Add new -> sabnzbd
        * HOST: 10.10.20.3
        * API key: get from Sabnzbd admin portal
        * leave all other as default and save
    * Go to Series -> Library import to import existing shows
    * Select tv and wait for it to scan, then import all
    * Go to Series and wait for it to detect any missing shows etc
    * For those with missing episodes, you can ask it to go grab them via Sabnzbd using the question mark button
* Radarr Setup
    * Go to radarr.<your domain>.ca
    * Configure authentication
        * Auth Method -> Forms (login page)
        * Choose Username and password
        * Save
    * Configure Media Management
        * Go to Settings -> Media Management
        * Click Show Advanced (top Left)
        * Enable Rename Episodes
        * Using https://trash-guides.info/Radarr/Radarr-recommended-naming-scheme
        * Use the Standard format: `{Movie CleanTitle} {(Release Year)} - {{Edition Tags}} {[MediaInfo 3D]}{[Custom Formats]}{[Quality Full]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[MediaInfo VideoDynamicRangeType]}{[Mediainfo VideoCodec]}{-Release Group}`
        * Add the /movies folder as a root folder
    * Set Quality Setting
        * Go to Settings -> Quality
        * Show advanced and follow the defaults shown here: https://trash-guides.info/Radarr/Radarr-Quality-Settings-File-Size/
    * Set up Custom Formats
        * Go to Settings -> Custom Formats
        * Add the following Custom formats from https://trash-guides.info/Radarr/Radarr-collection-of-custom-formats/ :
            * HDR
            * DV Boost
            * HDR10+ Boost
            * DV (w/o HDR Fallback)
            * UHD Bluray Tier 01
            * UHD Bluray Tier 02
            * UHD Bluray Tier 03
            * HD Bluray Tier 01
            * HD Bluray Tier 02
            * HD Bluray Tier 03
            * Remux Tier 01
            * Remux Tier 02
            * Remux Tier 03
            * WEB Tier 01
            * WEB Tier 02
            * WEB Tier 03
            * Repack/Proper
            * Repack2
            * Repack3
            * BR-DISK
            * Generated Dynamic HDR
            * LQ
            * LQ (Release Title)
            * 3D
            * Upscaled
            * Extras
            * Sing-Along Versions
            * AV1
            * AMZN
            * ATV
            * ATVP
            * BCORE
            * CRiT
            * DSNP
            * HBO
            * HMAX
            * Hulu
            * iT
            * MAX
            * MA
            * NF
            * PMTP
            * PCOK
            * PLAY
            * ROKU
            * STAN
            * TrueHD ATMOS
            * DTS X
            * ATMOS (undefined)
            * DD+ ATMOS
            * TrueHD
            * DTS-HD MA
            * FLAC
            * PCM
            * DTS-HD HRA
            * DD+
            * DTS-ES
            * DTS
            * AAC
            * DD
    * Configure Quality Profiles
        * Go to Settings -> Profiles
        * Make a 4K one with Remux-2160p, Blueray-2160p, WEB 2160p, HDTV-2160p
            * Upgrade until Web 2160
            * Language: Original
            * Follow the custom profiles shown here for UHD Bluray: https://trash-guides.info/Radarr/radarr-setup-quality-profiles 
                * Make sure to set the scores for the Custom Formats
        * make a 1080p one with Blu-ray 1080 and Web 1080
            * Upgrade until Web 1080
            * Language: Original
            * Follow the custom profiles shown here for HD Blueray: https://trash-guides.info/Radarr/radarr-setup-quality-profiles
                * Make sure to set the scores for the Custom Formats 
    * Configure Indexers
        * Go to Settings -> Indexers
        * Add new -> newznab
            * name: NZBgeek
            * url: https://api.nzbgeek.info
            * API path: /api
            * API key: Get key from nzbgeek profile
            * Categories: make sure UHD is also selected for TV
    * Configure Download clients
        * Go to Settings -> Download Clients
        * Add new -> sabnzbd
        * HOST: 10.10.20.3
        * API key: get from Sabnzbd admin portal
        * leave all other as default and save
    * Go to Movies -> Library import to import existing Movies
    * Select movies and wait for it to scan, then import all
    * Go to Movies and wait for it to detect any missing shows etc
* Tdarr setup
    * Go to `Tdarr.<your domain>.ca`
    * Go to Flow -> Add Flow
    * Add the following flow: [tdarr flow](./tdarr/tdarr-flow.json)
    * Go to Libraries Add a new one called "TV"
        * Source -> `/media`
        * Next tab: "Transcode Cache". Set to `/temp`
        * Output Folder: Leave default
        * Filters, leave as default except 'Filters at transcode queue level" add the following for resolutions: `480p,576p,720p`
        * Transcode Options: Select "Flows" and select the one added earlier "CPU HEVC"
        * Health Check: Default (Quick)
        * Leave Schedule and Variables as default
        * Start the scan of the files: Options -> Scan (Fresh)
    * On the home page select ServerNode -> Add one Transcode and one health check Workers for CPU
    * Lower down in Options, select Prioritise Health Check


