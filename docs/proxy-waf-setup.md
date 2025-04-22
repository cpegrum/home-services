# Intro
This git repo contains the docker files required to setup a CROWDSEC protected SWAG instance for proxying.

# Services
## CROWDSEC WAF + SWAG
This setup uses the following containers:
* crowdsec: This container runs the crowdsec engine which makes decisions on which users to block based in IP, traffic etc
* swag: This container hows the swag proxy. It also hosts the crowdsec bouncer which based on the decisions of the crowdsec engine will block access etc. This bouncer also feeds user request info to the crowdsec engine for decisions etc.

### Networks
* `proxynet`: `10.10.40.0/24` -> Internet enabled network 

### Setup
* Generate a random crowdsec API key using: `openssl rand -base64 24` Add this key to the `.env` file. (If this file doesn't exist in the root directory, copy the `.env.template` to `.env`)

* Make sure the `DOMAIN` variable in the `.env` file is filled with your domain.

* Make sure the `cloudflare.ini` file in `./secrets/` has the cloudflare API key to be able to get a SSL cert

* Edit the reverse-proxy confs in `./reverse-proxy` for:
    * `proxy-waf-open-webui.subdomain.conf`
    * `proxy-waf-plex.subdomain.conf`
* For each of the above files, edit the `upstream_app` variable to point to the IP of your open webui and plex server.

* Start the containers: `docker compose -f docker-compose-proxy-waf.yaml up -d --build`

### Testing
Testing works best when run from another computer (not the same one it is deployed on)
* You can test your setup by going to: `https://<your domain>/.env` you should get a crowdsec blocked msg

* You can verify that the block worked by entering the container via: `docker exec -it crowdsec bash` then going to `cscli metrics show appsec`

* To test a ban, go to the following URL on your instance: `https://<your domain>/CLASS.MODULE.CLASSLOADER.`, you may have to go more then once to trigger the ban
* You should now see a blocked page, enter the container to check the blocked status:
    * `docker exec -it crowdsec bash` then `cscli decisions list`, you should now see a blocked decision.
    * Use the following command to unblock it: `cscli decisions delete --id <ID number from list cmd>`
