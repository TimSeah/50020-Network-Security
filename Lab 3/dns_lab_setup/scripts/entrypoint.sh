#!/usr/bin/env bash
set -Eeuo pipefail

ROLE="${LAB_ROLE:-client}"
NORMAL_USER="${NORMAL_USER:-student}"
NORMAL_PASSWORD="${NORMAL_PASSWORD:-student}"

mkdir -p /run/sshd /run/named /var/cache/bind /var/log/lab
chown bind:bind /run/named /var/cache/bind

if ! id "$NORMAL_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$NORMAL_USER"
fi
printf '%s:%s\n' "$NORMAL_USER" "$NORMAL_PASSWORD" | chpasswd
usermod -aG sudo "$NORMAL_USER" || true
if getent group wireshark >/dev/null 2>&1; then
    usermod -aG wireshark "$NORMAL_USER" || true
fi

ssh-keygen -A >/dev/null 2>&1
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-dns-lab.conf <<'SSHEOF'
PasswordAuthentication yes
PermitRootLogin yes
UsePAM yes
SSHEOF

PIDS=()

# Avoid Docker's 127.0.0.11 DNS indirection for student-facing nodes.
if [[ "$ROLE" == "resolver" ]]; then
    printf 'nameserver 127.0.0.1\noptions timeout:2 attempts:2\n' > /etc/resolv.conf
else
    printf 'nameserver 10.11.2.6\noptions timeout:2 attempts:2\n' > /etc/resolv.conf
fi

start_bg() {
    "$@" &
    PIDS+=("$!")
}

start_bg /usr/sbin/sshd -D -e

make_rndc_key() {
    rm -f /etc/bind/rndc.conf /etc/rndc.conf /etc/rndc.key /etc/bind/rndc.key
    rndc-confgen -a -c /etc/bind/rndc.key -k rndc-key >/dev/null 2>&1
    chown root:bind /etc/bind/rndc.key
    chmod 0640 /etc/bind/rndc.key
}

case "$ROLE" in
    resolver)
        make_rndc_key
        if [[ ! -f /etc/bind/lab-dnssec.conf ]]; then
            printf 'dnssec-validation no;\n' > /etc/bind/lab-dnssec.conf
        fi
        named-checkconf /opt/dns-lab/config/node2/named.conf
        start_bg /usr/sbin/named -g -u bind -c /opt/dns-lab/config/node2/named.conf
        ;;

    authoritative)
        make_rndc_key
        named-checkconf -z /opt/dns-lab/config/node4/named.conf
        named-checkzone attackerpage.com /etc/bind/db.attackerpage.com >/dev/null
        named-checkzone example.com /etc/bind/db.example.com >/dev/null

        rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf
        cat > /etc/nginx/conf.d/dns-lab.conf <<'NGINXEOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name attackerpage.com www.attackerpage.com;
    root /opt/dns-lab/web/attackerpage;
    index index.html;
    location / { try_files $uri $uri/ =404; }
}

server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com login.example.com;
    root /opt/dns-lab/web/example;
    index index.html;
    location / { try_files $uri $uri/ =404; }
}
NGINXEOF
        nginx -t >/dev/null
        start_bg /usr/sbin/named -g -u bind -c /opt/dns-lab/config/node4/named.conf
        start_bg /usr/sbin/nginx -g 'daemon off;'
        ;;

    client|analyst)
        ;;

    *)
        echo "Unknown LAB_ROLE: $ROLE" >&2
        exit 2
        ;;
esac

terminate() {
    trap - TERM INT EXIT
    for pid in "${PIDS[@]:-}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait || true
}
trap terminate TERM INT EXIT

while true; do
    for pid in "${PIDS[@]}"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "A required service exited unexpectedly (PID $pid)." >&2
            wait "$pid" 2>/dev/null || true
            exit 1
        fi
    done
    sleep 1
done
