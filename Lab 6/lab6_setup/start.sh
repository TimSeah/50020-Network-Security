#!/usr/bin/env bash
set -euo pipefail

PROJECT=firewall_exam_monitoring_lab
NODES=(node1 node2 node3)

cd "$(dirname "$0")"
mkdir -p runtime/{node1,node2,node3,logs,shared}
chmod -R 0777 runtime

echo "============================================================"
echo " Firewall Setup, Evasion & AI Detection Lab"
echo "============================================================"

fail() {
  echo
  echo "[!] $*" >&2
  exit 1
}

step() {
  echo
  echo "[*] $*"
}

# ---------------------------------------------------------------------------
# Helper: configure a default route robustly across VirtualBox/VMware
# ---------------------------------------------------------------------------
set_stable_default_route() {
  local node="$1"
  local gateway="$2"
  local interface="$3"
  local label="$4"

  local stable_count=0

  echo "  configuring $label"

  # Docker/VM networking can still be settling immediately after compose up.
  # Give it a moment before replacing Docker's automatically installed route.
  sleep 2

  for attempt in {1..15}; do
    # Re-install the desired route on every attempt.
    docker exec "$node" \
      ip route replace default via "$gateway" dev "$interface" \
      >/dev/null 2>&1 || true

    sleep 1

    if docker exec "$node" sh -lc \
      "ip route show default | grep -Eq '^default via ${gateway}( |$)'"; then

      stable_count=$((stable_count + 1))

      # Require the route to be correct twice in a row.
      # This catches cases where Docker rewrites the route shortly afterward.
      if [[ "$stable_count" -ge 2 ]]; then
        echo "  ✓ $label -> $gateway"
        return 0
      fi
    else
      stable_count=0
    fi

    echo "    route not stable yet (attempt $attempt/15); retrying..."
  done

  echo
  echo "[!] $label could not be made stable."
  echo "[!] Actual routing table inside $node:"
  docker exec "$node" ip route | sed 's/^/    /' || true
  echo
  echo "[!] IPv4 interfaces inside $node:"
  docker exec "$node" ip -br -4 addr | sed 's/^/    /' || true

  return 1
}


step "Checking VM prerequisites..."
command -v docker >/dev/null 2>&1 || fail "docker is not installed"
command -v python3 >/dev/null 2>&1 || fail "python3 is required on the VM"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required"
docker info >/dev/null 2>&1 || fail "Docker daemon is not running"

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose -p "$PROJECT")
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose -p "$PROJECT")
else
  fail "docker compose/docker-compose is not available"
fi

[[ -n "${DISPLAY:-}" ]] || fail "DISPLAY is not set; run from the graphical VM desktop"

if command -v xhost >/dev/null 2>&1; then
  xhost +local: >/dev/null 2>&1 || true
fi


step "Removing stale lab resources..."
"${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1 || true

for n in node1 node2 node3; do
  docker rm -f "$n" >/dev/null 2>&1 || true
done

python3 - <<'PY'
import ipaddress
import json
import subprocess

targets = [
    ipaddress.ip_network("10.11.2.0/24"),
    ipaddress.ip_network("10.11.3.0/24"),
]

try:
    ids = subprocess.check_output(
        ["docker", "network", "ls", "-q"],
        text=True,
    ).split()
except Exception:
    ids = []

for nid in ids:
    try:
        info = json.loads(
            subprocess.check_output(
                ["docker", "network", "inspect", nid],
                text=True,
            )
        )[0]
    except Exception:
        continue

    name = info.get("Name", "")

    if name in ("bridge", "host", "none"):
        continue

    overlap = False

    for cfg in info.get("IPAM", {}).get("Config", []) or []:
        subnet = cfg.get("Subnet")

        if not subnet:
            continue

        try:
            network = ipaddress.ip_network(subnet, strict=False)
        except Exception:
            continue

        if any(network.overlaps(target) for target in targets):
            overlap = True
            break

    if not overlap:
        continue

    print(f"  removing conflicting Docker network: {name}")

    for cid in list((info.get("Containers") or {}).keys()):
        subprocess.run(
            ["docker", "rm", "-f", cid],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    subprocess.run(
        ["docker", "network", "rm", name],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
PY


step "Selecting the cached lab image..."

IMAGE_HASH="$({
  sha256sum container/Dockerfile
  sha256sum container/node-init.sh
  sha256sum container/lab-dns-proxy.py
  sha256sum container/firefox-wrapper.sh
  sha256sum container/firefox-as-seed.sh
  sha256sum container/wireshark-wrapper.sh
  sha256sum container/gedit-wrapper.sh
  sha256sum firefox/user.js
} | sha256sum | awk '{print substr($1,1,12)}')"

export LAB_IMAGE="firewall-exam-lab:${IMAGE_HASH}"

echo "  image: $LAB_IMAGE"

if docker image inspect "$LAB_IMAGE" >/dev/null 2>&1; then
  echo "  ✓ reusing local cached image"
else
  echo "  building image once; Docker will reuse cached package layers when available"
  docker build -t "$LAB_IMAGE" -f container/Dockerfile .
fi


step "Starting node1, node2 and node3..."
"${COMPOSE[@]}" up -d --no-build

for attempt in {1..30}; do
  all_ok=1

  for n in "${NODES[@]}"; do
    if [[ "$(docker inspect -f '{{.State.Running}}' "$n" 2>/dev/null || echo false)" != "true" ]]; then
      all_ok=0
    fi
  done

  [[ "$all_ok" -eq 1 ]] && break
  sleep 0.5
done

for n in "${NODES[@]}"; do
  if [[ "$(docker inspect -f '{{.State.Running}}' "$n" 2>/dev/null || echo false)" != "true" ]]; then
    echo "[!] $n exited. Recent log:"
    docker logs --tail 100 "$n" 2>&1 || true
    fail "$n failed to start"
  fi
done

echo "  ✓ all three containers are running"


check_ip() {
  local node="$1"
  local ip="$2"

  docker exec "$node" ip -o -4 addr show | grep -q "${ip}/" || {
    docker exec "$node" ip -br -4 addr || true
    fail "$node is missing $ip"
  }

  echo "  ✓ $node : $ip"
}


step "Checking addresses..."
check_ip node1 10.11.2.5
check_ip node2 10.11.2.6
check_ip node2 10.11.3.6
check_ip node3 10.11.3.7


iface_for() {
  local node="$1"
  local prefix="$2"

  docker exec "$node" sh -lc \
    "ip -o -4 addr show | awk '\$4 ~ /^${prefix}/ {print \$2; exit}'"
}


N1_IF="$(iface_for node1 '10[.]11[.]2[.]')"
N2_CAMPUS_IF="$(iface_for node2 '10[.]11[.]2[.]')"
N2_OUTSIDE_IF="$(iface_for node2 '10[.]11[.]3[.]')"

[[ -n "$N1_IF" ]] || fail "cannot find node1 campus interface"
[[ -n "$N2_CAMPUS_IF" ]] || fail "cannot find node2 campus interface"
[[ -n "$N2_OUTSIDE_IF" ]] || fail "cannot find node2 outside interface"

echo "  node1 campus : $N1_IF"
echo "  node2 campus : $N2_CAMPUS_IF"
echo "  node2 outside: $N2_OUTSIDE_IF"


step "Building the real routed path..."

# This is the VMware Fusion / VirtualBox portability fix.
#
# Docker initially installs its own bridge default gateways:
#   node1 may receive 10.11.2.1
#   node2 may receive a Docker-selected default route
#
# Our lab deliberately replaces them with:
#   node1 -> node2 (10.11.2.6)
#   node2 -> outside Docker gateway (10.11.3.1)
#
# On some VMware Fusion/Kali combinations, Docker networking finishes a little
# later and can overwrite a route that was changed immediately after compose up.
# Therefore we retry and require two consecutive successful checks.

set_stable_default_route \
  node1 \
  10.11.2.6 \
  "$N1_IF" \
  "node1 default route" \
  || fail "node1 default route could not be set to 10.11.2.6"

set_stable_default_route \
  node2 \
  10.11.3.1 \
  "$N2_OUTSIDE_IF" \
  "node2 outside default route" \
  || fail "node2 outside default route could not be set to 10.11.3.1"

docker exec node2 sysctl -w net.ipv4.ip_forward=1 >/dev/null

docker exec node2 sysctl net.ipv4.ip_forward \
  | grep -q '= 1' \
  || fail "IPv4 forwarding is disabled"

echo "  ✓ routing and forwarding are stable"


step "Selecting a working iptables/NAT backend..."

IPT_BACKEND=""

if docker exec node2 sh -lc \
  'command -v iptables-nft >/dev/null 2>&1 && iptables-nft -t nat -L -n >/dev/null 2>&1'; then

  IPT_BACKEND=nft

  docker exec node2 sh -lc \
    'update-alternatives --set iptables /usr/sbin/iptables-nft >/dev/null 2>&1 || true;
     update-alternatives --set ip6tables /usr/sbin/ip6tables-nft >/dev/null 2>&1 || true'

elif docker exec node2 sh -lc \
  'command -v iptables-legacy >/dev/null 2>&1 && iptables-legacy -t nat -L -n >/dev/null 2>&1'; then

  IPT_BACKEND=legacy

  docker exec node2 sh -lc \
    'update-alternatives --set iptables /usr/sbin/iptables-legacy >/dev/null 2>&1 || true;
     update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy >/dev/null 2>&1 || true'

else
  docker exec node2 sh -lc \
    'iptables --version 2>&1 || true;
     iptables-nft --version 2>&1 || true;
     iptables-legacy --version 2>&1 || true' \
    | sed 's/^/    /'

  fail "node2 has no usable NAT backend"
fi

echo "  ✓ using iptables-$IPT_BACKEND"


# Infrastructure only.
# Students create filtering policy themselves.
docker exec node2 iptables -P FORWARD ACCEPT

docker exec node2 iptables \
  -t nat \
  -C POSTROUTING \
  -s 10.11.2.0/24 \
  -o "$N2_OUTSIDE_IF" \
  -j MASQUERADE \
  2>/dev/null \
|| docker exec node2 iptables \
  -t nat \
  -A POSTROUTING \
  -s 10.11.2.0/24 \
  -o "$N2_OUTSIDE_IF" \
  -j MASQUERADE

docker exec node2 iptables -t nat -S POSTROUTING \
  | grep -q -- '-s 10.11.2.0/24' \
  || fail "NAT rule was not installed"

echo "  ✓ infrastructure NAT is active; student filtering policy is empty"


step "Starting campus DNS on node2..."

docker exec node2 sh -lc \
  'getent ahostsv4 example.com >/dev/null 2>&1' \
  || fail "node2 cannot resolve Internet DNS"

docker exec node2 sh -lc \
  "pkill -f '[l]ab-dns-proxy.py' 2>/dev/null || true"

docker exec -d node2 sh -lc \
  'exec python3 /usr/local/bin/lab-dns-proxy.py >>/workspace/lab-dns-proxy.log 2>&1'

for attempt in {1..20}; do
  if docker exec node2 sh -lc \
    "ss -lun | grep -q '10.11.2.6:53'"; then
    break
  fi

  sleep 0.25
done

docker exec node2 sh -lc \
  "ss -lun | grep -q '10.11.2.6:53'" \
  || {
    docker exec node2 tail -50 /workspace/lab-dns-proxy.log 2>/dev/null || true
    fail "campus DNS relay did not start"
  }

docker exec node1 sh -lc \
  "printf 'nameserver 10.11.2.6\noptions timeout:2 attempts:2 ndots:1\n' > /etc/resolv.conf"

docker exec node1 sh -lc \
  'getent ahostsv4 example.com >/dev/null 2>&1' \
  || fail "node1 cannot resolve Internet DNS through node2"

echo "  ✓ node1 DNS -> node2 10.11.2.6"


step "Checking external SSH jump host..."

if docker exec node1 sh -lc \
  "sshpass -p toor ssh \
     -o StrictHostKeyChecking=no \
     -o UserKnownHostsFile=/dev/null \
     -o ConnectTimeout=5 \
     root@10.11.3.7 'id -u'" \
  2>/dev/null \
  | grep -q '^0$'; then

  echo "  ✓ node1 can SSH to node3 using root/toor"

else
  docker logs --tail 100 node3 2>&1 || true
  fail "SSH jump host is not working"
fi


step "Checking GUI applications..."

for cmd in firefox wireshark gedit xdpyinfo; do
  docker exec node1 sh -lc \
    "command -v $cmd >/dev/null 2>&1" \
    || fail "$cmd is missing"
done

docker exec -u seed \
  -e HOME=/home/seed \
  node1 \
  sh -lc \
  'mkdir -p /home/seed/.config/wireshark &&
   test -w /home/seed/.config/wireshark' \
  || fail "seed GUI profile is not writable"

docker exec -u seed \
  -e HOME=/home/seed \
  -e DISPLAY="$DISPLAY" \
  node1 \
  sh -lc \
  'xdpyinfo >/dev/null 2>&1' \
  || fail "X11 does not work from node1"

# Confirm root-created workspace files are writable by root-mode gedit.
docker exec node2 sh -lc \
  'printf "# gedit write test\n" > /workspace/.gedit_write_test &&
   chmod 0644 /workspace/.gedit_write_test &&
   test -w /workspace/.gedit_write_test' \
  || fail "root workspace file is not writable for gedit"

docker exec node2 rm -f /workspace/.gedit_write_test \
  >/dev/null 2>&1 || true

echo "  ✓ GUI prerequisites are ready"


step "Checking Internet through the firewall/router..."

docker exec node3 sh -lc \
  'getent ahostsv4 example.com >/dev/null 2>&1' \
  || fail "node3 DNS/Internet is unavailable"

docker exec node3 sh -lc \
  'timeout 8 bash -c "</dev/tcp/example.com/443"' \
  2>/dev/null \
  || fail "node3 cannot reach Internet TCP/443"

docker exec node1 sh -lc \
  'timeout 8 bash -c "</dev/tcp/example.com/443"' \
  2>/dev/null \
  || {
    echo
    echo "[!] node1 route:"
    docker exec node1 ip route | sed 's/^/    /'

    echo
    echo "[!] node2 route:"
    docker exec node2 ip route | sed 's/^/    /'

    echo
    echo "[!] node2 NAT:"
    docker exec node2 iptables -t nat -L POSTROUTING -n -v \
      | sed 's/^/    /'

    fail "node1 cannot reach the Internet through node2"
  }

echo "  ✓ node1 Internet path is node1 -> node2 -> Internet"


step "Installing docksh..."

if [[ -w /usr/local/bin ]]; then

  install -m 0755 docksh /usr/local/bin/docksh

elif command -v sudo >/dev/null 2>&1; then

  sudo install -m 0755 docksh /usr/local/bin/docksh

else
  echo "  [!] could not install /usr/local/bin/docksh; use ./docksh"
fi


echo
echo "============================================================"
echo " LAB READY"
echo "============================================================"
echo "node1  10.11.2.5      Student workstation"
echo "node2  10.11.2.6      Campus firewall/router"
echo "       10.11.3.6      Outside interface"
echo "node3  10.11.3.7      External SSH jump host"
echo
echo "All docksh shells are root."
echo "Jump-host login: root / toor"
echo
echo "Enter nodes:"
echo "  docksh node1"
echo "  docksh node2"
echo "  docksh node3"
echo
echo "Normal web traffic:"
echo "  Firefox(node1) -> node2 firewall -> Internet"
echo
echo "Student filtering policy has NOT been created for you."
