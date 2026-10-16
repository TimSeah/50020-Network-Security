#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    DOCKER=(sudo docker)
else
    echo "Docker is not accessible. Removing host helper/runtime files only." >&2
    DOCKER=()
fi

if ((${#DOCKER[@]})); then
    if "${DOCKER[@]}" compose version >/dev/null 2>&1; then
        "${DOCKER[@]}" compose down --remove-orphans --volumes || true
    else
        for c in node1 node2 node3 node4; do "${DOCKER[@]}" rm -f "$c" >/dev/null 2>&1 || true; done
        "${DOCKER[@]}" network rm kali_dns_lab_net >/dev/null 2>&1 || true
    fi
    "${DOCKER[@]}" image rm kali-dns-lab:2026.09-real-example >/dev/null 2>&1 || true
fi

if [[ -f .runtime/docksh.installed ]]; then
    if [[ -e .runtime/docksh.backup || -L .runtime/docksh.backup ]]; then
        if [[ -w /usr/local/bin ]]; then
            rm -f /usr/local/bin/docksh
            cp -a .runtime/docksh.backup /usr/local/bin/docksh
        elif command -v sudo >/dev/null 2>&1; then
            sudo rm -f /usr/local/bin/docksh
            sudo cp -a .runtime/docksh.backup /usr/local/bin/docksh
        fi
    else
        if [[ -w /usr/local/bin ]]; then
            rm -f /usr/local/bin/docksh
        elif command -v sudo >/dev/null 2>&1; then
            sudo rm -f /usr/local/bin/docksh
        fi
    fi
fi

rm -rf .runtime .env
printf 'DNS lab stopped and lab-specific runtime resources removed.\n'
