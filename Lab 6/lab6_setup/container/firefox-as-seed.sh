#!/usr/bin/env bash
set -euo pipefail

export HOME=/home/seed
export USER=seed
export LOGNAME=seed
export XDG_CONFIG_HOME=/home/seed/.config
export XDG_CACHE_HOME=/home/seed/.cache
export XDG_DATA_HOME=/home/seed/.local/share

mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" /home/seed/.mozilla
profile=/workspace/firefox-profile
mkdir -p "$profile"
cp /opt/lab/firefox/user.js "$profile/user.js"

exec dbus-launch --exit-with-session /usr/bin/firefox \
  --no-remote --profile "$profile" "$@"
