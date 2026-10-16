# Teaching Flow

## Demo 1 — topology

```bash
docker compose ps
docksh node1
docksh node2
docksh node3
docksh node4
```

Roles:

```text
node1  10.11.2.5  client
node2  10.11.2.6  recursive/caching resolver
node3  10.11.2.7  analyst
node4  10.11.2.8  authoritative lab DNS + web
```

## Demo 2 — real `example.com` recursion

On node2:

```bash
flushcache
wireshark &
```

Capture `eth0`.

On node1:

```bash
dig example.com
```

Explain:

```text
node1 -> node2:53
node2 -> public DNS hierarchy
node2 -> node1
```

With a cold cache, node2 should contact Internet DNS servers itself instead of forwarding every query to one upstream resolver.

## Demo 3 — client TXID versus resolver TXID

Observe:

```text
node1 -> node2       TXID = X
node2 -> Internet    TXID = Y
Internet -> node2    TXID = Y
node2 -> node1       TXID = X
```

Also observe node2's configured UDP source port `12345` for iterative DNS queries.

Optional passive helper on node2:

```bash
dns_ids
```

## Demo 4 — cache and delegation records

On node2:

```bash
flushcache
```

On node1:

```bash
dig example.com
```

On node2:

```bash
dumpcache
dumpcache example.com
```

For the raw cache:

```bash
rndc dumpdb -cache
less /var/cache/bind/cache_dump.db
```

Run the same `dig example.com` again and compare Wireshark traffic.

## Demo 5 — fresh negative public lookup

On node2:

```bash
flushcache
```

On node1:

```bash
dig abc-does-not-exist.example.com
```

Observe the public negative response and then inspect:

```bash
dumpcache example.com
```

## Demo 6 — resolve the lab nameserver

On node1:

```bash
dig ns.attackerpage.com
```

Expected:

```text
10.11.2.8
```

This query goes through node2's lab-only `attackerpage.com` forward zone.

## Demo 7 — directly query node4's private `example.com`

On node1:

```bash
dig @ns.attackerpage.com example.com
dig @ns.attackerpage.com example.com NS
```

Expected private lab data:

```text
example.com.  A   10.11.2.8
example.com.  NS  ns.attackerpage.com.
```

Compare this with:

```bash
dig example.com
```

Key distinction:

```text
dig example.com
    -> node2 -> real public DNS

dig @ns.attackerpage.com example.com
    -> direct query to node4 -> node4's private lab zone
```

Node2 has no `example.com` override.

## Demo 8 — edit the zone like an operator

On node4:

```bash
gedit /etc/bind/db.example.com &
```

Edit a record, keep or change:

```text
example.com. NS ns.attackerpage.com.
```

and increment the SOA serial.

Validate and reload:

```bash
reloadzone example.com
```

On node1:

```bash
dig @ns.attackerpage.com example.com NS
dig @ns.attackerpage.com example.com A
```

Explain that changing this private zone does not change the real `.com` parent delegation, so normal `dig example.com` remains public.

## Demo 9 — demonstration webpage

The private node4 `example.com` A record is `10.11.2.8`.

From node1:

```bash
curl --resolve example.com:80:10.11.2.8 http://example.com/
```

The page contains a simple static demonstration login table.

## Demo 10 — DNSSEC

On node2:

```bash
dnssec-status
dnssec-on
dnssec-off
```
