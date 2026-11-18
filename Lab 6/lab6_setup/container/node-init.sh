#!/usr/bin/env bash
set -u

mkdir -p /run/sshd /workspace /logs /shared

# docksh / docker exec sessions are root by design, but desktop applications
# are launched as the unprivileged 'seed' user. Ensure seed's complete desktop
# profile is writable on every container boot. This prevents Wireshark/gedit/
# Firefox from inheriting root-owned XDG directories.
install -d -o seed -g seed -m 0755 \
  /home/seed \
  /home/seed/.config \
  /home/seed/.config/wireshark \
  /home/seed/.cache \
  /home/seed/.local \
  /home/seed/.local/share \
  /home/seed/.mozilla
chown -R seed:seed /home/seed
chmod 0755 /home/seed

ssh-keygen -A >/dev/null 2>&1 || true
echo 'seed:toor' | chpasswd
echo 'root:toor' | chpasswd
chmod 0777 /workspace /logs /shared 2>/dev/null || true

# Keep container boot deliberately simple. Routing, forwarding, NAT and firewall
# setup are applied by start.sh only after Docker confirms all nodes are alive.
/usr/sbin/sshd || {
  echo "[!] sshd failed on $(hostname)" >&2
  /usr/sbin/sshd -t >&2 || true
}

cat <<MSG
============================================================
$(hostname) base container ready
============================================================
MSG
ip -br -4 addr || true
ip route || true

exec tail -f /dev/null
