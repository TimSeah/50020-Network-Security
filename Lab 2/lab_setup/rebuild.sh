#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
./stop.sh
docker image rm -f three-node-tcp-lab-gedit:local >/dev/null 2>&1 || true
./start.sh
