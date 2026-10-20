#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lab-common.sh"
as_root "$@"
if [[ ! -e "$STATE_ROOT/$MARKER" ]]; then
  echo 'No managed Example Campus Service lab found; no changes made.'
  exit 0
fi
require_managed_or_absent "$WEB_ROOT" "$MARKER"
check_conf_owned
if [[ -f "$SITE_CONF" ]]; then
  a2dissite -q "$SITE_NAME" || true
  rm -f -- "$SITE_CONF"
  if systemctl is-active --quiet apache2; then apache2ctl configtest && systemctl reload apache2; fi
fi
if command -v mariadb >/dev/null 2>&1 && systemctl is-active --quiet mariadb; then
  mariadb --protocol=socket -uroot <<'SQL'
DROP DATABASE IF EXISTS `example_campus_training`;
DROP USER IF EXISTS 'example_campus_app'@'localhost';
SQL
fi
remove_host_aliases
if [[ -f "$WEB_ROOT/$MARKER" ]]; then rm -rf -- "$WEB_ROOT"; fi
rm -rf -- "$STATE_ROOT"
echo 'Example Campus Service website, Apache virtual hosts and dedicated lab database/account removed.'
echo 'Your existing Kali IP and unrelated Apache/MariaDB data were not removed.'
echo 'Apache and MariaDB packages/services were left installed.'
