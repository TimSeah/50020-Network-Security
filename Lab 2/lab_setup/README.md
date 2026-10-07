# Student 3-node TCP Docker lab

Start a clean lab:

```bash
./start.sh
```

End the session and remove the runtime containers/network:

```bash
./stop.sh
```

The local image and `./shared` coursework are preserved, so the next
`./start.sh` is clean and fast.

## Nodes

```text
10.11.2.0/24

node1  10.11.2.5
node2  10.11.2.6
node3  10.11.2.7
```

## Credentials

```text
kali / kali
root / toor
```

## Default TCP sysctls

```text
net.ipv4.tcp_syncookies=0
net.ipv4.tcp_synack_retries=5
net.ipv4.tcp_max_syn_backlog=128
```

Enter as root:

```bash
docksh node1
```

Students can change them inside a running container:

```bash
sysctl -w net.ipv4.tcp_syncookies=1
sysctl -w net.ipv4.tcp_max_syn_backlog=256
sysctl -w net.ipv4.tcp_synack_retries=3
```

A fresh `./stop.sh` then `./start.sh` restores the Compose defaults.

## Python + Scapy

Installed and verified:

```python
from scapy.all import IP, TCP, send
from ipaddress import IPv4Address
from random import getrandbits
from scapy.all import *
```

Run shared Python files:

```bash
docksh node1
python3 /shared/lab.py
```

## Wireshark

```bash
docksh node1
wireshark
```

Normally capture `eth0`.

## Gedit

Gedit is installed in every node, together with the small X11/D-Bus support
needed to run it from a container shell. Enter a node with `docksh` so the
lab can pass the host X11 display and authorization cookie into the container.

```bash
docksh node2
gedit /shared/tcp_attack_detector.py &
```

Do not enter the container with plain `docker exec` when you want a GUI;
`docksh` sets `DISPLAY` and `XAUTHORITY` for you.

Also available:

```text
tshark
tcpdump
```

## SSH / Telnet

```bash
ssh kali@10.11.2.6
telnet 10.11.2.6 23
```

## Netcat

`nc` is installed in every container via `netcat-openbsd`.

Start a TCP listener on node2:

```bash
docksh node2
nc -lvnp 6666
```

From node1, connect to it:

```bash
docksh node1
nc -nv 10.11.2.6 6666
```

Anything typed on either side is carried over the TCP connection. Because all
three nodes share the isolated `10.11.2.0/24` Docker network, no host port
mapping is needed for node-to-node Netcat connections.

## Shared folder

Host:

```text
./shared
```

Every container:

```text
/shared
```

## Host requirements

On Kali:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose xauth
sudo systemctl enable --now docker
```

Then:

```bash
./start.sh
```

## Deep clean

Normal end-of-session cleanup:

```bash
./stop.sh
```

Removes:
- all three containers
- lab network
- orphans

Preserves:
- `./shared`
- `three-node-tcp-lab-gedit:local`

Full image purge:

```bash
./stop.sh --purge-image
```

Next `./start.sh` rebuilds automatically.

Rebuild after changing the Dockerfile:

```bash
./rebuild.sh
```

## Arbitrary random source IPs

Every node automatically starts with:

```text
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.eth0.rp_filter=0

10.11.2.0/24 dev eth0
default dev sink0
```

`sink0` is a Linux dummy interface inside the container. Incoming spoofed SYNs
still arrive through `eth0`, while SYN+ACK replies to addresses outside the lab
subnet are routed to `sink0` and consumed locally. They are not sent toward
Docker NAT or an external network.

Verify on node2:

```bash
docksh node2
ip route
ip route get 10.11.2.100
ip route get 8.8.8.8
sysctl net.ipv4.conf.all.rp_filter
sysctl net.ipv4.conf.eth0.rp_filter
tcpdump -ni sink0
```

A generator using all possible 32-bit values can still occasionally produce
special-use source addresses such as multicast, loopback, broadcast, or
unspecified addresses. Linux can reject some of those before the TCP layer.
Ordinary random unicast IPv4 sources are the intended case.


## Fixed rp_filter initialization

Some Docker/Kali hosts can create the container `eth0` with:

```text
net.ipv4.conf.eth0.rp_filter = 2
```

even when the entrypoint requested `0`.

This version fixes that after Docker finishes creating all three network
interfaces. `start.sh` explicitly runs, in every container:

```bash
sysctl -w net.ipv4.conf.all.rp_filter=0
sysctl -w net.ipv4.conf.default.rp_filter=0
sysctl -w net.ipv4.conf.eth0.rp_filter=0
```

It then reasserts:

```text
10.11.2.0/24 -> eth0
default       -> sink0
```

before `verify.sh` runs.

After startup, check:

```bash
docksh node2

sysctl net.ipv4.conf.all.rp_filter
sysctl net.ipv4.conf.eth0.rp_filter
ip route
```

Expected:

```text
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.eth0.rp_filter = 0
```


## `rp_filter=2` is accepted in this final version

Linux defines:

```text
0 = disabled
1 = strict
2 = loose
```

Some Kali/Docker hosts reapply `2` to container `eth0`. This is acceptable for
this lab because loose mode only rejects a source when the source is not
reachable through any interface. The lab installs:

```text
default dev sink0
```

so ordinary arbitrary unicast sources are reachable via `sink0`.

The verifier therefore:
- accepts `rp_filter=0`,
- accepts `rp_filter=2`,
- rejects strict mode `1`,
- confirms arbitrary unicast addresses route to `sink0`,
- sends a controlled spoofed SYN from node3 to node2,
- confirms node2 actually creates a `SYN-RECV` entry.

This validates the actual TCP-lab behavior rather than requiring a sysctl value
that Docker/Kali may overwrite.


## Interactive `sysctl -w` support

This version uses:

```yaml
privileged: true
```

for each lab container.

Docker's normal container configuration marks `/proc/sys` read-only. That
allows Compose to set namespaced sysctls when the container is created, but
prevents students from changing them later with `sysctl -w`.

Privileged mode removes that read-only restriction for this disposable,
isolated teaching lab.

After:

```bash
./start.sh
docksh node2
```

these commands should now persist immediately:

```bash
sysctl -w net.ipv4.tcp_syncookies=1
sysctl -w net.ipv4.tcp_max_syn_backlog=50
sysctl -w net.ipv4.tcp_synack_retries=3
```

Verify:

```bash
sysctl net.ipv4.tcp_syncookies
sysctl net.ipv4.tcp_max_syn_backlog
sysctl net.ipv4.tcp_synack_retries
```

`start.sh`/`verify.sh` automatically test this write-and-read-back behavior on
all three containers, then restore the requested defaults.

### Security boundary

`privileged: true` is intentionally broad. Use this lab only inside the
disposable Kali/VirtualBox teaching VM and keep the Docker lab network
`internal: true`. Do not use this Compose configuration for an exposed or
multi-tenant Docker host.
