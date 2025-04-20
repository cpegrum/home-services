# Intro
This git repo will contain all the Configuration as Code used to setup my home AI Server

# Services
## AI Server
Ollama Server with Open-Webui frontend.
### Container
This setup contains 3 different containers:
* Ollama: This container hosts and runs the AI models. It is connected to the `ainet` network.
* Open-Webui: This container hosts the Web frontend that allows for easy use of the AI models run by Ollama. It is connected to the `ainet` network.
* swag: This reverse proxy provides SSL certs for the Open-Webui frontend. It is connected to the `ainet` network with ports `80` and `443` exposed to allow external use.

### Networks
* `ainet`: `10.10.30.0/24` -> Internet enabled network

### Setup
First make sure you Ubuntu machine is setup to allow AI models to run. See [VM setup](./dmz-ai-server-setup.md) for more details.

* Make sure the `.env` file and the `secrets/cloudflare.ini` file are filled in with the web domain and cloudflare key in order for SWAG to be able to generate the SSL certificates.

* Next Start the containers using: `docker compose -f docker-compose-dmz-ai.yaml up -d --build`
* Once the containers are up, enter the `ollama` container to download and install some models
    * `docker exec -it ollama bash`
    * Download the `gemma3:27b` model: `ollama pull gemma3:27b`
    * Download the `llama3.3:70b` model: `ollama pull llama3.3:70b`

* Go to the domain for the open-webui: `https://api.<your domain>`
* Create the admin user by entering in a new password and email

* Once logged in, time to start configuring the UI.
    * Go to Admin Settings: Profile picture -> Admin Panel
    * Go to Users -> Groups
        * Add new Group called "Normal-Users"
    * Go to Settings -> Models
        * Click on Edit (pencil) and give Read permission to "Normal-Users"
    * Add a User, go to Users -> Click the plus and add the user details
        * Go to Groups -> "Normal-Users" and add the user above to this group
    * They will now be able to login and use the server!