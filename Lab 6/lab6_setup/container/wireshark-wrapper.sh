#!/usr/bin/env bash
set -euo pipefail

launch_wireshark() {
  export HOME=/home/seed
  export USER=seed
  export LOGNAME=seed
  export XDG_CONFIG_HOME=/home/seed/.config
  export XDG_CACHE_HOME=/home/seed/.cache
  export XDG_DATA_HOME=/home/seed/.local/share
  mkdir -p "$XDG_CONFIG_HOME/wireshark" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"

  # Do not inherit a root-owned lab/workspace directory as Wireshark's CWD.
  # GTK/Wireshark may inspect files in the current directory, which can cause
  # permission warnings such as: "you don't have permission to read IOR.txt".
  cd /home/seed

  exec dbus-launch --exit-with-session /usr/bin/wireshark "$@"
}

if [[ "$(id -u)" -eq 0 ]]; then
  # Repair ownership in case a previous root command created desktop files.
  install -d -o seed -g seed -m 0755 \
    /home/seed/.config /home/seed/.config/wireshark \
    /home/seed/.cache /home/seed/.local/share
  chown -R seed:seed /home/seed

  # Launch Wireshark from seed's home rather than root's current directory.
  cd /home/seed

  exec runuser -u seed -- env \
    HOME=/home/seed USER=seed LOGNAME=seed \
    XDG_CONFIG_HOME=/home/seed/.config \
    XDG_CACHE_HOME=/home/seed/.cache \
    XDG_DATA_HOME=/home/seed/.local/share \
    DISPLAY="${DISPLAY:-:0}" \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    dbus-launch --exit-with-session /usr/bin/wireshark "$@"
fi

launch_wireshark "$@"
