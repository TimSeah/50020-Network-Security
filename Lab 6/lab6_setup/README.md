# Firewall Setup, Evasion & AI Detection Lab — Student Setup

This ZIP contains **only the lab environment**. It does not include the
instructor guide, firewall solution, website-blocking helper, attack generator,
or detector implementation.

## Final topology

```text
node1 — Student workstation
10.11.2.5
   |
   | campus network 10.11.2.0/24
   v
node2 — Campus firewall/router
10.11.2.6   campus interface
10.11.3.6   outside interface
   |
   | outside network 10.11.3.0/24
   v
node3 — External SSH jump host
10.11.3.7
   |
   v
Internet
```

Normal browser traffic is real routed traffic:

```text
Firefox inside node1
       ↓
10.11.2.5
       ↓
node2 FORWARD firewall
       ↓
node2 NAT
       ↓
Internet
```

## Start

Run from the graphical VM desktop:

```bash
chmod +x start.sh stop.sh docksh diagnose.sh
./start.sh
```

Do not begin until you see:

```text
LAB READY
```

## Enter containers

```bash
docksh node1
docksh node2
docksh node3
```

All shells open as `root`.

The external SSH jump host is `node3`:

```text
IP:       10.11.3.7
Username: root
Password: toor
```

## GUI programs

From `node1`:

```bash
firefox &
```

From `node2`, for packet capture/inspection:

```bash
wireshark &
gedit /workspace/notes.txt &
```

For example, if you create a root-owned firewall script:

```bash
touch /workspace/firewall.sh
chmod 644 /workspace/firewall.sh
gedit /workspace/firewall.sh &
```

`gedit` can save it because both the shell and editor are running as root.

Firefox and Wireshark wrappers run those desktop applications as `seed` while
keeping the same container/network namespace. `gedit` is different: it runs as
the current shell user. Because `docksh` opens a root shell, `gedit` also runs
as root so it can save root-owned files created during firewall administration.

## Expected baseline

Inside node1:

```bash
ip route
```

Expected default route:

```text
default via 10.11.2.6
```

DNS should point to the campus firewall/router:

```bash
cat /etc/resolv.conf
```

Expected:

```text
nameserver 10.11.2.6
```

Before you configure filtering policy, normal websites should be reachable in
Firefox.

## Important

`start.sh` creates routing, DNS and NAT infrastructure only. It intentionally
leaves the forwarding filter open. Creating, testing, inspecting and removing
firewall rules is part of the assignment.

## Reset

```bash
./stop.sh
./start.sh
```

The cached Docker image is retained for faster restarts.

## Troubleshooting

```bash
./diagnose.sh
```
