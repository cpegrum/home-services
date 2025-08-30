 # Steps for normal Ubuntu VM

 This guide will cover how to setup a Ubuntu (24.04 LTS) VM for use with the AI docker containers

 Note that this guide assumes that you have NVIDIA GPUs available and connected to run the models on.

## Steps
### General Server Setup
* Server ISO with minimal install and LVM disk
* Install updates while installing
* username dev + strong password
* Once finished installing boot into Ubuntu

* apt update and upgrade
* Make it a static IP (if adding a Domain name to your DNS Resolver)

* install ssh server `apt install openssh-server`
* add SSH key
    * create ~/.ssh/authorized_keys
    * check permissions: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys`
    * add SSH pub key
* enable ufw firewall
  * ufw app list
  * allow SSH `ufw allow OpenSSH`
  * don't configure ports for docker based services as docker avoids ufw
  * show rules: `ufw show added`
  * enable: `ufw enable`
  * check status: `ufw status`
* install docker: https://docs.docker.com/engine/install/ubuntu/
    * make sure to add the linux post install to give docker privs to dev user

### AI Specific Setup
* Install Nvidia Drivers:
    * Check to see if GPus are installed: `lshw -C display`, Should see 2 if 2 GPUs installed
    * Get Nvidia Drivers repo: `sudo add-apt-repository ppa:graphics-drivers/ppa -y`
    * List drivers: `ubuntu-drivers devices`
    * Install recommended: `   sudo apt install nvidia-driver-570`
    * Reboot: `reboot now`
    * Check drivers: `nvidia-smi`
    * List all gpus: `lspci | grep -i vga`

* Install Nvidia Container runtime: see https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installation for more details
    * Configure repo:
    ```
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    ```
    * Update and install: `sudo apt-get update` and `sudo apt-get install -y nvidia-container-toolkit`

* Tell Docker to use nvidia: `nvidia-ctk runtime configure --runtime=docker`

* Configure the following settings for the docker deamon to fix this issue: [ollama github](https://github.com/ollama/ollama/blob/main/docs/troubleshooting.md#linux-docker)

```
# Edit /etc/docker/daemon.json and add the following

{
  "exec-opts": ["native.cgroupdriver=cgroupfs"]
}

```

* restart docker: `sudo systemctl restart docker`