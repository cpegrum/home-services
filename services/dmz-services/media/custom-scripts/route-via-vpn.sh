#!/bin/bash
# Routes all traffic from this container via the wireguard VPN container.
# Mounted into /custom-cont-init.d, which linuxserver images run as root on every container start
# (including restarts by Docker after a reboot or crash). Requires cap_add: NET_ADMIN.
ip route replace default via 10.10.20.2
