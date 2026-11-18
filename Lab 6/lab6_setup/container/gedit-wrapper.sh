#!/usr/bin/env bash
set -euo pipefail

# docksh opens a root shell by design. Files created from that shell are often
# root-owned (for example /workspace/firewall.sh). Run gedit as the SAME user
# that invoked it so a root shell can edit/save root-owned lab files.
#
# Firefox and Wireshark remain intentionally unprivileged via their own
# wrappers; only the text editor follows the current shell user.

if [[ "$(id -u)" -eq 0 ]]; then
  install -d -o root -g root -m 0755 \
    /root/.config /root/.cache /root/.local /root/.local/share
  export HOME=/root
  export USER=root
  export LOGNAME=root
  export XDG_CONFIG_HOME=/root/.config
  export XDG_CACHE_HOME=/root/.cache
  export XDG_DATA_HOME=/root/.local/share
  export DISPLAY="${DISPLAY:-:0}"
  exec dbus-launch --exit-with-session /usr/bin/gedit "$@"
fi

# Non-root fallback: use the caller's own home/profile.
export DISPLAY="${DISPLAY:-:0}"
exec dbus-launch --exit-with-session /usr/bin/gedit "$@"
