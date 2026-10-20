#!/usr/bin/env bash
set -Eeuo pipefail
LAB_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
WEB_ROOT='/var/www/example-campus-training'
STATE_ROOT='/var/lib/example-campus-training'
SITE_CONF='/etc/apache2/sites-available/example-campus-training.conf'
SITE_NAME='example-campus-training.conf'
DB_NAME='example_campus_training'
DB_USER='example_campus_app'
DB_PASS='only_for_local_classroom'
MARKER='.example-campus-managed'
RELEASE_ID='v5'
EXTERNAL_PORT=8082
INTERNAL_PORT=8081


# Local hostnames: the portal and document publisher have distinct cookie hosts.
# They remain on Kali's existing IP and are never advertised through public DNS.
HOSTS_MARKER='# Example Campus Service managed hosts'
write_host_aliases() {
  local ip_addr
  ip_addr="$(portal_ip)"
  # Respect aliases managed independently by the VM owner.
  if grep -E '(^|[[:space:]])(portal[.]campus[.]test|docs[.]campus[.]test)([[:space:]]|$)' /etc/hosts | grep -vF "$HOSTS_MARKER" >/dev/null; then
    echo 'ERROR: A campus.test hostname already exists in /etc/hosts. Resolve the conflict before installing.' >&2
    exit 1
  fi
  sed -i '/# Example Campus Service managed hosts$/d' /etc/hosts
  printf '%s portal.campus.test docs.campus.test %s\n' "$ip_addr" "$HOSTS_MARKER" >> /etc/hosts
}
remove_host_aliases() {
  sed -i '/# Example Campus Service managed hosts$/d' /etc/hosts
}

as_root() {
  if (( EUID != 0 )); then
    command -v sudo >/dev/null 2>&1 || { echo 'ERROR: sudo is needed to configure Apache and MariaDB.' >&2; exit 1; }
    exec sudo -- "$LAB_ROOT/$(basename "$0")" "$@"
  fi
}

# Prefer the user-facing 10.0.2.x interface. Otherwise prefer the interface
# used for the default route, then the first non-loopback global IPv4 address.
detect_portal_ip() {
  local ip iface
  ip="$(ip -4 -o addr show scope global 2>/dev/null | awk '$4 ~ /^10[.]0[.]2[.]/ {sub(/\/.*/, "", $4); print $4; exit}')"
  if [[ -n "$ip" ]]; then printf '%s\n' "$ip"; return 0; fi
  iface="$(ip -4 route show default 2>/dev/null | awk '/^default / {for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
  if [[ -n "$iface" ]]; then
    ip="$(ip -4 -o addr show dev "$iface" scope global 2>/dev/null | awk 'NR==1 {sub(/\/.*/, "", $4); print $4}')"
    if [[ -n "$ip" ]]; then printf '%s\n' "$ip"; return 0; fi
  fi
  ip="$(ip -4 -o addr show scope global 2>/dev/null | awk 'NR==1 {sub(/\/.*/, "", $4); print $4}')"
  if [[ -n "$ip" ]]; then printf '%s\n' "$ip"; return 0; fi
  echo 'ERROR: No usable Kali IPv4 address detected. Run ip -4 addr and check networking.' >&2
  return 1
}

validate_portal_ip() {
  local ip_addr="$1"
  [[ "$ip_addr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: invalid IPv4 address: $ip_addr" >&2; return 1; }
  [[ "$ip_addr" != '127.0.0.1' ]] || { echo 'ERROR: choose the VM interface address, not loopback.' >&2; return 1; }
  if ! ip -4 -o addr show | awk '{split($4,a,"/"); print a[1]}' | grep -Fxq "$ip_addr"; then
    echo "ERROR: $ip_addr is not configured on your Kali VM. Run: ip -4 addr" >&2
    return 1
  fi
}

portal_ip() {
  if [[ -r "$STATE_ROOT/portal-ip" ]]; then cat "$STATE_ROOT/portal-ip";
  else detect_portal_ip; fi
}

require_managed_or_absent() {
  local target="$1" marker="$2"
  if [[ -L "$target" ]]; then echo "ERROR: $target is a symlink; refusing to modify it." >&2; exit 1; fi
  if [[ -e "$target" && ! -e "$target/$marker" ]]; then
    echo "ERROR: $target already exists and is not this lab's workspace. Aborting." >&2; exit 1
  fi
}

check_conf_owned() {
  if [[ -e "$SITE_CONF" ]] && ! grep -q '^# Example Campus Service classroom lab managed file$' "$SITE_CONF"; then
    echo "ERROR: Apache config already exists but isn't managed by this lab: $SITE_CONF" >&2; exit 1
  fi
}

editor_user() {
  local account="${SUDO_USER:-}"
  if [[ -n "$account" && "$account" != root ]]; then printf '%s' "$account";
  else printf 'root'; fi
}

check_service() {
  local service="$1"
  systemctl enable --now "$service" >/dev/null 2>&1 || {
    echo "ERROR: Failed to start $service. Check: sudo journalctl -u $service -n 50" >&2; exit 1;
  }
}

create_database() {
  mariadb --protocol=socket -uroot <<SQL
DROP DATABASE IF EXISTS \`$DB_NAME\`;
CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT SELECT,INSERT,UPDATE,DELETE ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
SQL
  mariadb --protocol=socket -uroot "$DB_NAME" < "$LAB_ROOT/db/init.sql"
}

refresh_shared_page() {
  # Publish the separate document-share portal.
  mkdir -p "$WEB_ROOT/share"
  cp -a -- "$LAB_ROOT/share/." "$WEB_ROOT/share/"
  local editor
  editor="$(editor_user)"
  chown -R "$editor:$editor" "$WEB_ROOT/share"
  find "$WEB_ROOT/share" -type f -exec chmod 644 {} +
}

reset_files() {
  require_managed_or_absent "$WEB_ROOT" "$MARKER"
  mkdir -p "$WEB_ROOT"
  touch "$WEB_ROOT/$MARKER"
  rm -rf -- "$WEB_ROOT/site" "$WEB_ROOT/share" "$WEB_ROOT/internal" "$WEB_ROOT/internal-data" "$WEB_ROOT/share-pages"
  cp -a -- "$LAB_ROOT/site" "$WEB_ROOT/site"
  cp -a -- "$LAB_ROOT/internal" "$WEB_ROOT/internal"
  cp -a -- "$LAB_ROOT/share" "$WEB_ROOT/share"
  install -d -m 750 -o www-data -g www-data "$WEB_ROOT/internal-data" "$WEB_ROOT/share-pages"
  # Create one instance-specific plaintext config, outside all web document roots.
  # Random training keys are generated on each complete reset.
  local api_key session_key encryption_key
  api_key="demo_asset_$(openssl rand -hex 12)"
  session_key="demo_$(openssl rand -hex 24)"
  encryption_key="DEMO-$(openssl rand -hex 16)"
  cat > "$WEB_ROOT/internal-data/internal-service.conf" <<CONFIG
# /etc/campus/internal-service.conf
# Example Campus Service - Internal Operations
# Access classification: IT administrators only

[identity]
service_account = svc-campus-sync
service_password = Welcome123!
default_admin_password = ChangeMeNow123
session_signing_key = $session_key

[integration]
asset_inventory_url = http://inventory.internal.example/api/v1
api_access_key = $api_key
backup_username = campus-backup
backup_password = BackupOnly123

[security]
audit_events = enabled
legacy_token_validation = disabled
allow_internal_http = true
backup_encryption_key = $encryption_key
CONFIG
  chown -R www-data:www-data "$WEB_ROOT/internal-data" "$WEB_ROOT/share-pages"
  chmod 750 "$WEB_ROOT/internal-data" "$WEB_ROOT/share-pages"
  chmod 640 "$WEB_ROOT/internal-data/internal-service.conf"
  install -d -m 700 -o www-data -g www-data "$STATE_ROOT/sessions"
  find "$STATE_ROOT/sessions" -type f -name 'sess_*' -delete
  local editor
  editor="$(editor_user)"
  chown -R "$editor:$editor" "$WEB_ROOT/site" "$WEB_ROOT/share" "$WEB_ROOT/internal"
  find "$WEB_ROOT/site" "$WEB_ROOT/share" "$WEB_ROOT/internal" -type d -exec chmod 755 {} +
  find "$WEB_ROOT/site" "$WEB_ROOT/share" "$WEB_ROOT/internal" -type f -exec chmod 644 {} +
  refresh_shared_page
}

write_apache_conf() {
  check_conf_owned
  local ip_address
  ip_address="$(portal_ip)"
  validate_portal_ip "$ip_address"
  cat > "$SITE_CONF" <<APACHE
# Example Campus Service classroom lab managed file
# Classroom only: client requests must originate from the Kali VM.
Listen $ip_address:$INTERNAL_PORT
Listen $ip_address:$EXTERNAL_PORT
<VirtualHost $ip_address:80>
    ServerName portal.campus.test
    DocumentRoot "$WEB_ROOT/site"
    DirectoryIndex index.php
    <Directory "$WEB_ROOT/site">
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require local
    </Directory>
    SetEnv DB_HOST localhost
    SetEnv DB_NAME $DB_NAME
    SetEnv DB_USER $DB_USER
    SetEnv DB_PASSWORD $DB_PASS
    Header always set X-Content-Type-Options "nosniff"
    ErrorLog \${APACHE_LOG_DIR}/campus-portal-error.log
    CustomLog \${APACHE_LOG_DIR}/campus-portal-access.log combined
</VirtualHost>
<VirtualHost $ip_address:$EXTERNAL_PORT>
    ServerName docs.campus.test
    DocumentRoot "$WEB_ROOT/share"
    DirectoryIndex index.php
    <Directory "$WEB_ROOT/share">
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require local
    </Directory>
    Header always set X-Content-Type-Options "nosniff"
    ErrorLog \${APACHE_LOG_DIR}/campus-share-error.log
    CustomLog \${APACHE_LOG_DIR}/campus-share-access.log combined
</VirtualHost>
<VirtualHost $ip_address:$INTERNAL_PORT>
    ServerName portal.campus.test
    DocumentRoot "$WEB_ROOT/internal"
    DirectoryIndex index.php
    <Directory "$WEB_ROOT/internal">
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require local
    </Directory>
    SetEnv DB_HOST localhost
    SetEnv DB_NAME $DB_NAME
    SetEnv DB_USER $DB_USER
    SetEnv DB_PASSWORD $DB_PASS
    Header always set X-Content-Type-Options "nosniff"
    ErrorLog \${APACHE_LOG_DIR}/campus-internal-error.log
    CustomLog \${APACHE_LOG_DIR}/campus-internal-access.log combined
</VirtualHost>
APACHE
}

reload_apache() {
  apache2ctl configtest
  if systemctl is-active --quiet apache2; then systemctl restart apache2;
  else systemctl start apache2; fi
}
