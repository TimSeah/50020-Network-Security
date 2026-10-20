#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lab-common.sh"
as_root "$@"
if [[ ! -f "$STATE_ROOT/$MARKER" || ! -f "$WEB_ROOT/$MARKER" ]]; then
  echo 'Lab not installed. Run ./start.sh first.' >&2; exit 1
fi
check_conf_owned
write_host_aliases
check_service mariadb
printf '[Example Campus Service] RESET: live PHP edits, stored comments and preferences will be deleted.\n'
reset_files
create_database
printf '%s\n' "$RELEASE_ID" > "$STATE_ROOT/release"
write_apache_conf
reload_apache
# Browser sessions are invalidated by regenerating the PHP session storage only if safe;
# here we request users to sign out and log in after resetting.
echo 'Reset complete: original site, sessions, published shared documents and database restored.'
echo 'For a fresh teaching run, sign out/in or open a private browser window.'
