#!/usr/bin/env bash
set -euo pipefail

# Firefox is intentionally run as the normal desktop user even when docksh
# provides a root shell. Its network namespace is still node1.
if [[ "$(id -u)" -eq 0 ]]; then
  install -d -o seed -g seed -m 0755 \
    /home/seed/.config /home/seed/.cache /home/seed/.local/share /home/seed/.mozilla
  chown -R seed:seed /home/seed
  exec runuser -u seed -- env \
    HOME=/home/seed USER=seed LOGNAME=seed \
    XDG_CONFIG_HOME=/home/seed/.config \
    XDG_CACHE_HOME=/home/seed/.cache \
    XDG_DATA_HOME=/home/seed/.local/share \
    DISPLAY="${DISPLAY:-:0}" \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /usr/local/libexec/firefox-as-seed "$@"
fi

export HOME=/home/seed
export USER=seed
export LOGNAME=seed
export XDG_CONFIG_HOME=/home/seed/.config
export XDG_CACHE_HOME=/home/seed/.cache
export XDG_DATA_HOME=/home/seed/.local/share
exec /usr/local/libexec/firefox-as-seed "$@"
