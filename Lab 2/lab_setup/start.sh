#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

IMAGE="three-node-tcp-lab-gedit:local"
compose_cmd=()

as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed." >&2
    echo "Install on Kali:" >&2
    echo "  sudo apt update" >&2
    echo "  sudo apt install -y docker.io docker-compose xauth" >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    as_root systemctl enable --now docker || true
fi

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is unavailable." >&2
    exit 1
fi

if docker compose version >/dev/null 2>&1; then
    compose_cmd=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    compose_cmd=(docker-compose)
else
    echo "ERROR: Docker Compose is not installed." >&2
    echo "On Kali: sudo apt install -y docker-compose" >&2
    exit 1
fi

if ! command -v xauth >/dev/null 2>&1; then
    echo "[host] Installing xauth..."
    as_root apt-get update
    as_root apt-get install -y xauth
fi

mkdir -p shared
chmod 0777 shared

chmod +x entrypoint.sh wireshark-wrapper docksh start.sh setup.sh stop.sh rebuild.sh verify.sh
as_root install -m 0755 docksh /usr/local/bin/docksh

# Always begin with a clean runtime. Preserve ./shared and the local image.
for c in lab-node1 lab-node2 lab-node3; do
    docker rm -f "$c" >/dev/null 2>&1 || true
done
docker network rm three-node-tcp-lab-net >/dev/null 2>&1 || true


if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "=== First-time image build ==="
    docker build -t "$IMAGE" .
else
    echo "[ OK ] Local image exists; build skipped."
fi

echo "=== Creating/starting lab nodes ==="
"${compose_cmd[@]}" up -d --no-build --remove-orphans

sleep 1

echo "=== Finalizing rp_filter and sink routes ==="
for c in lab-node1 lab-node2 lab-node3; do
    docker exec "$c" sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null
    docker exec "$c" sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null
    docker exec "$c" sysctl -w net.ipv4.conf.eth0.rp_filter=0 >/dev/null

    docker exec "$c" sh -c '
        ip link show sink0 >/dev/null 2>&1 || ip link add sink0 type dummy
        ip link set sink0 up

        ip -4 addr show dev sink0 | grep -q "10\.255\.255\.1/32" ||             ip addr add 10.255.255.1/32 dev sink0

        while ip route del default >/dev/null 2>&1; do :; done
        ip route replace default dev sink0
    '
done

echo "=== Verifying lab ==="
./verify.sh

cat <<'EOF'

LAB READY

Random-source routing:
  rp_filter=0
  10.11.2.0/24 -> eth0
  everything else -> sink0

node1  10.11.2.5
node2  10.11.2.6
node3  10.11.2.7

Credentials:
  kali / kali
  root / toor

Enter as root:
  docksh node1
  docksh node2
  docksh node3

Inside a container:
  python3
  wireshark
  gedit
  tshark
  tcpdump
  ssh
  telnet
  nc

Gedit example:
  gedit /shared/tcp_attack_detector.py &

Netcat example:
  nc -lvnp 6666

Scapy imports available:
  from scapy.all import IP, TCP, send
  from ipaddress import IPv4Address
  from random import getrandbits
  from scapy.all import *

Writable TCP sysctls:
  sysctl -w net.ipv4.tcp_syncookies=1
  sysctl -w net.ipv4.tcp_max_syn_backlog=256
  sysctl -w net.ipv4.tcp_synack_retries=3

Shared:
  host: ./shared
  nodes: /shared
EOF
