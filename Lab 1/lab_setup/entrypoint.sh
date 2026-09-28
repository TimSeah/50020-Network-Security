#!/usr/bin/env bash
set -euo pipefail

mkdir -p /run/sshd /shared
chmod 0777 /shared
rm -f /run/nologin /etc/nologin

# Allow arbitrary unicast spoofed source addresses arriving on eth0.
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null
sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null
if [[ -e /proc/sys/net/ipv4/conf/eth0/rp_filter ]]; then
    sysctl -w net.ipv4.conf.eth0.rp_filter=0 >/dev/null
fi

# Local dummy sink for all non-lab return traffic.
if ! ip link show sink0 >/dev/null 2>&1; then
    ip link add sink0 type dummy
fi
ip link set sink0 up

if ! ip -4 addr show dev sink0 | grep -q '10\.255\.255\.1/32'; then
    ip addr add 10.255.255.1/32 dev sink0
fi

# Keep 10.11.2.0/24 directly connected on eth0, but send every other
# destination to sink0 so replies cannot leave the container/lab.
while ip route del default >/dev/null 2>&1; do
    :
done
ip route add default dev sink0

ssh-keygen -A >/dev/null 2>&1

if ! pgrep -x inetd >/dev/null 2>&1; then
    /usr/sbin/inetd /etc/inetd.conf
fi

exec /usr/sbin/sshd -D -e
