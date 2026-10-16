# Kali DNS Lab — Real `example.com` Recursion + Direct Lab Authority

This four-node Docker lab uses Kali Linux containers and keeps two DNS paths deliberately separate:

1. `dig example.com` uses node2 as a real recursive/caching resolver and follows the public DNS hierarchy.
2. `dig @ns.attackerpage.com example.com` explicitly asks node4, which hosts an independent lab-only authoritative copy of `example.com` that points to `10.11.2.8`.

This is intentional. Node2 does **not** override or forward `example.com` to node4.

## Topology

```text
node1  user        10.11.2.5   normal DNS client
node2  localdns    10.11.2.6   recursive/caching BIND resolver
node3  analyst     10.11.2.7   analyst workstation
node4  attackerns  10.11.2.8   authoritative BIND + Nginx
```

Docker network: `10.11.2.0/24`, gateway `10.11.2.1`.

Normal accounts/passwords:

```text
node1: user / user
node2: localdns / localdns
node3: analyst / analyst
node4: attackerns / attackerns
```

`docksh node1`, `docksh node2`, etc. open a root Bash shell.

## Start

```bash
./start.sh
```

Force a clean image rebuild:

```bash
./start.sh --rebuild
```

Check local infrastructure without generating public DNS traffic:

```bash
./check.sh
```

Test real Internet recursion separately:

```bash
./check.sh --internet
```

## DNS logic

### Normal public lookup

From node1:

```bash
dig example.com
```

The path is:

```text
node1 10.11.2.5
   |
   | query example.com
   v
node2 10.11.2.6
   |
   | iterative DNS queries, UDP source port 12345
   v
root -> .com -> public authoritative DNS for example.com
   |
   v
node2 cache
   |
   v
node1
```

There is no global forwarding resolver. Node2 performs recursion itself using the DNS hierarchy.

A cold-cache capture on node2 should therefore show queries to multiple DNS servers rather than every request going to one address such as `192.168.2.100`.

### Lab nameserver discovery

Node2 has one selective lab-only forward zone:

```text
attackerpage.com -> node4 10.11.2.8
```

This exists so node1 can resolve:

```bash
dig ns.attackerpage.com
```

Expected address:

```text
10.11.2.8
```

### Direct query to node4's private `example.com`

Node4 also loads an independent authoritative zone named `example.com`.

That private copy is **not delegated to node4 by the real Internet** and node2 does not redirect normal `example.com` requests to it.

To query it explicitly:

```bash
dig @ns.attackerpage.com example.com
```

Expected lab answer:

```text
example.com.  A  10.11.2.8
```

To inspect the NS record on node4:

```bash
dig @ns.attackerpage.com example.com NS
```

Expected:

```text
example.com.  NS  ns.attackerpage.com.
```

This provides the comparison:

```text
dig example.com
    -> node1 -> node2 -> real public DNS hierarchy

dig @ns.attackerpage.com example.com
    -> resolve ns.attackerpage.com -> 10.11.2.8
    -> query node4 directly
    -> node4's private example.com zone
```

## Editing `/etc/bind/db.example.com`

On node4:

```bash
docksh node4
```

Open the zone exactly like a normal BIND operator:

```bash
gedit /etc/bind/db.example.com &
```

or:

```bash
vim /etc/bind/db.example.com
```

Initial contents include:

```text
example.com.          NS  ns.attackerpage.com.
example.com.          A   10.11.2.8
www.example.com.      A   10.11.2.8
login.example.com.    A   10.11.2.8
```

After editing a record, increment the SOA serial, for example:

```text
2026091501 -> 2026091502
```

Then validate and reload:

```bash
reloadzone example.com
```

Expected output:

```text
Reloaded example.com.
```

The helper runs `named-checkzone` first and only then asks BIND to reload the zone.

Test the changed private zone from node1:

```bash
dig @ns.attackerpage.com example.com NS
dig @ns.attackerpage.com example.com A
```

Important: changing `/etc/bind/db.example.com` on node4 does not alter the real `.com` parent delegation. Therefore a normal:

```bash
dig example.com
```

still follows public DNS through node2.

## Demonstration web page

Node4 runs Nginx and has a simple static `example.com` demonstration page containing a login table. It does not submit, store, or process credentials.

Because normal `example.com` DNS remains public, use the lab address explicitly while preserving the HTTP Host header:

```bash
curl --resolve example.com:80:10.11.2.8 http://example.com/
```

or:

```bash
curl -H 'Host: example.com' http://10.11.2.8/
```

This should display the lab page hosted on `10.11.2.8`.

## Cache demonstration

On node2:

```bash
flushcache
```

Expected output:

```text
Flushed.
```

Start Wireshark on node2:

```bash
wireshark &
```

Capture `eth0`, then from node1 run:

```bash
dig example.com
```

Back on node2:

```bash
dumpcache
dumpcache example.com
```

The concise cache viewer displays useful cached RRsets including:

```text
A
AAAA
CNAME
DNAME
NS
SOA
negative/NXDOMAIN entries
```

For the unfiltered BIND cache:

```bash
rndc dumpdb -cache
less /var/cache/bind/cache_dump.db
```

Run `dig example.com` again and compare the packet trace with the first lookup. Depending on TTLs and cache state, fewer external lookups should be needed.

## Transaction IDs

The client-to-resolver transaction and resolver-to-authoritative transaction are independent.

Conceptually:

```text
node1 -> node2      TXID = X
node2 -> Internet   TXID = Y
Internet -> node2   TXID = Y
node2 -> node1      TXID = X
```

Use the passive helper on a node where the traffic is visible:

```bash
dns_ids
```

It displays only source/destination IPs and ports, DNS TXID, query/response, and query name. It does not inject or modify packets.

## Resolver source port

node2 is configured with the SEED-style fixed outbound UDP DNS source port:

```text
12345
```

For iterative traffic you should see flows similar to:

```text
10.11.2.6:12345 -> authoritative-server:53
```

Current BIND versions retain this syntax for compatibility, although fixed source ports are not recommended for production resolvers.

## DNSSEC

DNSSEC validation is disabled by default.

On node2:

```bash
dnssec-status
dnssec-on
dnssec-off
```

## Wireshark

Inside a container:

```bash
wireshark &
```

Capture interface:

```text
eth0
```

CLI alternative:

```bash
tcpdump -ni eth0
```

Expected visibility:

```text
node1: node1 <-> node2, plus traffic node1 sends directly to node4
node2: client DNS plus its own recursive Internet DNS traffic
node4: traffic actually addressed to node4
```

node4 should not normally see unrelated node1-to-node2 unicast traffic.

## Python packages

The image permits normal classroom package installation:

```bash
pip3 install <module>
```

Scapy is already installed.

## Stop and cleanup

```bash
./stop.sh
```

The script removes only this lab's containers, network, image/runtime files, and installed `docksh` helper. It does not perform a global Docker prune.

## Troubleshooting public `SERVFAIL`

If this works:

```bash
dig @ns.attackerpage.com example.com
```

but this fails:

```bash
dig example.com
```

run:

```bash
./check.sh --internet
```

If direct root-server DNS is blocked, the lab will report that the surrounding VM/VPN/university network does not permit full iterative recursion. That is different from a failure of node4's local authoritative zones.

To test a root server manually from node2:

```bash
dig +norecurse @198.41.0.4 . NS
```

## Useful commands

```bash
./start.sh
./start.sh --rebuild
./check.sh
./check.sh --internet
./stop.sh

docksh node1
docksh node2
docksh node3
docksh node4

# node2
flushcache
dumpcache
dumpcache example.com
rndc status
rndc dumpdb -cache
dnssec-status
dnssec-on
dnssec-off
dns_ids

# node4
gedit /etc/bind/db.example.com &
reloadzone example.com

# node1
dig example.com
dig ns.attackerpage.com
dig @ns.attackerpage.com example.com
dig @ns.attackerpage.com example.com NS
curl --resolve example.com:80:10.11.2.8 http://example.com/
```
