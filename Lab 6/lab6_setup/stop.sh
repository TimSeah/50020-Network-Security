#!/usr/bin/env bash
set -u
PROJECT=firewall_exam_monitoring_lab
cd "$(dirname "$0")"

if docker compose version >/dev/null 2>&1; then
  docker compose -p "$PROJECT" down --remove-orphans 2>/dev/null || true
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose -p "$PROJECT" down --remove-orphans 2>/dev/null || true
fi

for n in node1 node2 node3; do
  docker rm -f "$n" >/dev/null 2>&1 || true
done

rm -rf runtime
mkdir -p runtime/{node1,node2,node3,logs,shared}
chmod -R 0777 runtime
echo "[+] Containers and lab runtime state cleared."
echo "[+] Cached Docker image retained for fast next start."
