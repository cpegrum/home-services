#!/bin/sh
# Sleep and route show to allow newtwork to get running, error otherwise
sleep 10
ip route show
# Configure ip route to wireguard VPN container
ip route delete default
ip route add default via 10.10.20.2

# Start Bind9 Server
/usr/sbin/named -u bind -f -c /etc/bind/named.conf -L /var/log/bind/default.log