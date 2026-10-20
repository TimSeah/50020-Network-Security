#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lab-common.sh"
if (( $# > 1 )); then echo 'Usage: ./start.sh [KALI_IP]' >&2; exit 2; fi
as_root "$@"
require_managed_or_absent "$WEB_ROOT" "$MARKER"
# Refuse to replace a different pre-existing site bound to the internal port.
for old_conf in /etc/apache2/sites-available/*.conf; do
  [[ -f "$old_conf" && "$old_conf" != "$SITE_CONF" ]] || continue
  if grep -Eq '^[[:space:]]*Listen[[:space:]]+[0-9.]+:8081([[:space:]]|$)' "$old_conf"; then
    echo 'ERROR: Another lab/service already declares port 8081. Stop the older installation first.' >&2
    exit 1
  fi
done
check_conf_owned
# A previous release must be explicitly reset before deploying revised PHP/DB.
# Otherwise a successful start can mistakenly leave old, broken code running.
if [[ -f "$WEB_ROOT/$MARKER" && -f "$STATE_ROOT/$MARKER" ]]; then
  current_release="$(cat "$STATE_ROOT/release" 2>/dev/null || true)"
  if [[ "$current_release" != "$RELEASE_ID" ]]; then
    echo "ERROR: An older lab release is installed (${current_release:-pre-v5})." >&2
    echo "Run ./restart.sh from this extracted v5 folder to replace the files and reset the sample database." >&2
    echo "WARNING: ./restart.sh deletes existing lab edits and records." >&2
    exit 1
  fi
fi
if ! command -v apt-get >/dev/null 2>&1; then
  echo 'ERROR: This installer targets Kali Linux (APT-based).' >&2; exit 1
fi
printf '[Example Campus Service] Installing/confirming Apache, PHP, MariaDB and utilities...\n'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apache2 libapache2-mod-php php-mysql mariadb-server curl iproute2 openssl
if ! command -v gedit >/dev/null 2>&1; then
  echo 'NOTE: gedit not found; install it if you want GUI editing (not required by the web app).'
fi
# Optional address allows manual selection on multi-interface Kali VMs.
new_ip="${1:-$(detect_portal_ip)}"
validate_portal_ip "$new_ip"
[[ "$new_ip" != '127.0.0.1' ]] || exit 1
if [[ -e "$STATE_ROOT" && ! -e "$STATE_ROOT/$MARKER" && -n "$(ls -A "$STATE_ROOT")" ]]; then
  echo "ERROR: $STATE_ROOT belongs to another installation; refusing to overwrite." >&2; exit 1
fi
mkdir -p "$STATE_ROOT"
touch "$STATE_ROOT/$MARKER"
printf '%s\n' "$new_ip" > "$STATE_ROOT/portal-ip"
write_host_aliases
check_service mariadb
if [[ ! -f "$WEB_ROOT/$MARKER" ]]; then
  reset_files
  create_database
  printf '%s\n' "$RELEASE_ID" > "$STATE_ROOT/release"
else
  echo '[Example Campus Service] Leaving edited portal source files and database unchanged.'
  # Refresh the document-sharing landing page.
  refresh_shared_page
fi
a2enmod -q env headers
write_apache_conf
a2ensite -q "$SITE_NAME"
reload_apache
printf '\n[Example Campus Service] Kali-native lab ready (NO Docker).\n'
printf ' Portal:        http://portal.campus.test/\n'
printf ' Internal file: http://portal.campus.test:%s/secret/ (admin only)\n' "$INTERNAL_PORT"
printf ' Document share: http://docs.campus.test:%s/\n' "$EXTERNAL_PORT"
printf ' IP address:    http://%s/ (redirects to the portal hostname)\n' "$new_ip"
printf ' Source files:  %s/site/\n' "$WEB_ROOT"
printf ' Edit:          gedit %s/site/login.php\n' "$WEB_ROOT"
printf ' Full reset:    ./restart.sh\n Remove lab:    ./stop.sh\n'
