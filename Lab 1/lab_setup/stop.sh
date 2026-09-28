#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

compose_cmd=()

if docker compose version >/dev/null 2>&1; then
    compose_cmd=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    compose_cmd=(docker-compose)
else
    echo "ERROR: Docker Compose is not installed." >&2
    exit 1
fi

echo "=== Deep-cleaning lab runtime ==="

"${compose_cmd[@]}" down \
    --remove-orphans \
    --timeout 1

for c in lab-node1 lab-node2 lab-node3; do
    docker rm -f "$c" >/dev/null 2>&1 || true
done

docker network rm three-node-tcp-lab-net >/dev/null 2>&1 || true

echo "[ OK ] Containers removed"
echo "[ OK ] Lab network removed"
echo "[ OK ] ./shared preserved"
echo "[ OK ] three-node-tcp-lab-gedit:local preserved"
echo
echo "Next session: ./start.sh"

if [[ "${1:-}" == "--purge-image" ]]; then
    docker image rm -f three-node-tcp-lab-gedit:local >/dev/null 2>&1 || true
    echo "[ OK ] Local image removed; next start.sh will rebuild"
elif [[ -n "${1:-}" ]]; then
    echo "Usage: ./stop.sh [--purge-image]" >&2
    exit 1
fi
