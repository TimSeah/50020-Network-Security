#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

echo "=== Containers ==="
docker ps -a --format 'table {{.Names}}\t{{.Status}}' | grep -E 'NAMES|node1|node2|node3' || true

for n in node1 node2 node3; do
  echo
  echo "=== $n ==="
  docker inspect "$n" >/dev/null 2>&1 || { echo "missing"; continue; }
  echo "running: $(docker inspect -f '{{.State.Running}}' "$n" 2>/dev/null)"
  echo "configured user: $(docker inspect -f '{{.Config.User}}' "$n" 2>/dev/null)"
  docker exec "$n" sh -lc 'echo -n "whoami: "; whoami; ip -br -4 addr; echo "-- routes --"; ip route' 2>/dev/null || true
done

echo
echo "=== node1 DNS ==="
docker exec node1 cat /etc/resolv.conf 2>/dev/null || true
docker exec node1 sh -lc 'getent ahostsv4 sutd.edu.sg | head' 2>/dev/null || true

echo
echo "=== node2 forwarding/NAT/filter ==="
docker exec node2 sysctl net.ipv4.ip_forward 2>/dev/null || true
docker exec node2 iptables --version 2>/dev/null || true
docker exec node2 iptables -t nat -L POSTROUTING -n -v 2>/dev/null || true
docker exec node2 iptables -L FORWARD -n -v --line-numbers 2>/dev/null || true

echo
echo "=== GUI ==="
docker exec -u seed -e HOME=/home/seed -e DISPLAY="${DISPLAY:-:0}" node1 sh -lc 'xdpyinfo >/dev/null 2>&1 && echo X11_OK || echo X11_FAIL' 2>/dev/null || true
