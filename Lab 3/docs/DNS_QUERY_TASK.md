# Construct a DNS Query and Receive a Response

## Goal and packet structure

Run `../scripts/dns_query.py` on node3 (`10.11.2.7`) to request the A record
for `example.com` from node2 (`10.11.2.6`). Node2 constructs the real response;
this task does not require forging a DNS response or running `attack.py`.

The packet is Ethernet / IPv4 / UDP / DNS. Scapy constructs the DNS header
and question. Python's UDP socket lets the operating system choose the source
port and construct the UDP/IP headers, lengths, and checksums. It also keeps
that source port open to receive the reply. Root is not required for the query
script, although capturing traffic requires suitable privileges.

The script sets a random 16-bit transaction ID, `QR=0`, standard-query
`Opcode=0`, and `RD=1`. Its one question is `example.com`, type `A` (IPv4
address), class `IN` (Internet). It checks the reply's transaction ID, response
flag, opcode, and question before displaying it. DNS errors, timeouts, empty
answers, and truncation are reported rather than presented as a successful lookup.

## Prepare the containers

Use the Linux/X11 lab host where the lab's Docker setup runs. From the
repository root, start the lab if it is not already running:

```bash
cd "Lab 3/dns_lab_setup"
./start.sh
./check.sh
cd ../..
docker cp "Lab 3/scripts/dns_query.py" node3:/tmp/dns_query.py
docker exec node3 python3 -c 'import scapy; print(scapy.__version__)'
```

The image already includes Scapy. If your running container lacks it:

```bash
docker exec -it node3 pip3 install scapy
```

No Docker image rebuild or Compose changes are needed to copy this script.
Repeat `docker cp` after changing the host script.

## Capture on both nodes

1. In a host terminal, open node2 and start Wireshark:

   ```bash
   docker exec -it node2 bash
   wireshark -i eth0 -k &
   ```

2. In a second host terminal, open node3 and start Wireshark:

   ```bash
   docker exec -it node3 bash
   wireshark -i eth0 -k &
   ```

3. Make sure both captures are running before executing the script. In both
   Wireshark windows, enter this **display filter**:

   ```text
   dns && ip.addr == 10.11.2.6 && ip.addr == 10.11.2.7
   ```

   If the interface name differs, use `ip -br addr` inside the container to
   find the interface with its `10.11.2.x` address. If Wireshark cannot open its
   display, check the host's X11 setup and the startup script's diagnostics.
   The query script does not require a GUI, but this task requires Wireshark
   captures on both nodes.

4. In the node3 shell, run:

   ```bash
   python3 /tmp/dns_query.py example.com
   ```

   The output should identify the client source port and transaction ID,
   display the DNS request and reply, and end with:

   ```text
   Received a matching DNS response with answer records.
   ```

5. Stop both captures. Each should show the same pair:

   ```text
   Query:    10.11.2.7:<client-port> -> 10.11.2.6:53
   Response: 10.11.2.6:53 -> 10.11.2.7:<client-port>
   ```

   The DNS transaction ID must match in the query and response. Use the
   actual ID and port printed by your script, not invented example values.
   Node2 may also capture public DNS recursion traffic, which this display
   filter excludes.

## Screenshots to submit

Take four screenshots, two from each node:

- **Node3 query:** Keep the query and response visible in the packet list.
  Select the query and expand IPv4, UDP, and DNS, including the question.
- **Node3 response:** Select the matching response and expand UDP, DNS flags,
  and Answers so the returned address and TTL are visible.
- **Node2 query:** Show the same incoming query with the endpoints, UDP ports,
  transaction ID, and question expanded.
- **Node2 response:** Show the outgoing response with the matching transaction
  ID and answer expanded.

Make the node identity clear in each screenshot, for example by including its
shell with `hostname` and `ip -br addr` output. Save both captures as `.pcapng`
and place screenshots in `Lab 3/screenshots/`. Screenshot evidence must come
from your actual run; the offline script checks are not evidence of a lab
network exchange.

## Important fields

| Field | Meaning in this exchange |
| --- | --- |
| IPv4 source/destination | Query: node3 to node2; response: node2 to node3. |
| UDP source/destination ports | The query uses an OS-selected client port and destination port 53. The response uses source port 53 and destination equal to that client port. |
| UDP length | Length of the UDP header (8 bytes) plus its DNS payload, not the whole Ethernet frame. |
| UDP checksum | Detects corruption using the UDP header, payload, and IP pseudo-header. Capture offloading can cause an apparent checksum warning before the checksum is finalized. |
| DNS transaction ID | A 16-bit value echoed by the response to associate it with the query. |
| QR and Opcode | QR is 0 for the query and 1 for the response; Opcode 0 means a standard query. |
| RD and RA | RD=1 requests recursion; RA=1 in node2's response indicates recursion is available. |
| AA | Indicates an authoritative answer. Node2 is a recursive resolver, so its public `example.com` response is normally not authoritative (AA=0). |
| TC | Indicates truncation. Expect TC=0 for this small answer; TC=1 requires a TCP retry, which this script reports but does not perform. |
| RCODE | Response result: 0 is NOERROR; 2 is SERVFAIL; 3 is NXDOMAIN. A DNS reply alone does not prove a successful A lookup. |
| QDCOUNT / ANCOUNT / NSCOUNT / ARCOUNT | Numbers of questions, answer records, authority records, and additional records. This query has one question; read the response counts from your capture. |
| QNAME / QTYPE / QCLASS | `example.com`, A (numeric type 1), and IN (numeric class 1). |
| Answer NAME / TYPE / RDATA | The record owner, record type, and returned IPv4 address for an A record. Multiple A answers are valid. |
| Answer TTL | Remaining cache lifetime of the record in seconds. Cached responses may show a lower TTL. |

Node2 follows public DNS for `example.com`. Do not assume its response will
contain `10.11.2.8`: that address belongs to node4's separate private zone,
which this task does not query.

## Brief report wording

Adapt this paragraph to your actual captures and include the observed source
port, transaction ID, answer address(es), and TTL:

> The Python program on node3 (10.11.2.7) sent an A/IN query for example.com
> to node2 (10.11.2.6) using UDP destination port 53 and an ephemeral source
> port. The response reversed the IP addresses and UDP ports and echoed the
> query's DNS transaction ID. The query used QR=0 and RD=1; the successful
> response used QR=1, RA=1, and RCODE=0 and included the requested A record(s).
> The answer TTL specifies how long the records can remain cached. Captures
> on both nodes show the query and its matching response, confirming the
> request reached node2 and the reply returned to node3.

Use this success wording only after confirming those fields in your captures.

## If the lookup fails

- Timeout: verify both nodes are running, the destination is `10.11.2.6`,
  and BIND is listening on node2. Inspect the capture for a query without a
  reply. Retry with `python3 /tmp/dns_query.py example.com --timeout 30`.
- SERVFAIL: node2 may be unable to reach the public DNS hierarchy. From the
  lab setup directory, run `./check.sh --internet`. Do not change node2's
  resolver configuration just to force a desired answer.
- To separate public-recursion problems from a local exchange problem, this
  is another valid A query supported by the lab:

  ```bash
  python3 /tmp/dns_query.py ns.attackerpage.com
  ```

  Node2 forwards this lab zone to node4; the expected A record is `10.11.2.8`.
  If you use this alternative in your submission, explain and capture that
  name instead of claiming the query was for `example.com`.