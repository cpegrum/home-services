#!/bin/bash

# point DNS to the Bind9 DNS container
echo "nameserver 10.10.20.4" >> /etc/resolv.conf

# Configure ip route to wireguard VPN container
ip route add default via 10.10.20.2
