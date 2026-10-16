# Task 3 — DNS Query and Response

## Python query

I ran [`dns_query.py`](../scripts/dns_query.py) on node3 to request the A record for `ns.attackerpage.com` from node2 (`10.11.2.6`). The program built the DNS message with Scapy, sent it through a UDP socket, and checked that the returned DNS transaction ID and question matched the query.

The node3 and node2 captures show the same exchange:

| Field | Query | Response |
| --- | --- | --- |
| IP source → destination | `10.11.2.7` → `10.11.2.6` | `10.11.2.6` → `10.11.2.7` |
| UDP source → destination port | `40396` → `53` | `53` → `40396` |
| DNS transaction ID | `0x2c84` | `0x2c84` |
| DNS flags | Query (`QR=0`), recursion desired (`RD=1`) | Response (`QR=1`), recursion desired and available (`RD=1`, `RA=1`), no error (`RCODE=0`) |
| DNS question | `ns.attackerpage.com`, type A, class IN | Same question |

The response contained one answer, `ns.attackerpage.com A 10.11.2.8` with a 300-second TTL, and one authority record, `attackerpage.com NS ns.attackerpage.com`, also with a 300-second TTL. Matching addresses, reversed UDP ports, transaction ID, and question identify it as the response to this query. The terminal confirmed: “Received a matching DNS response with answer records.”

## Forged response observation

In the separate forged-response run, [`attack.py`](../scripts/attack.py) sent a reply proposing `66.66.66.66` and `ns.attackerpage.com` for `gwgsz.example.com`. Node2 captured it at 88.293861702 s, before its upstream query at 91.634874463 s. The forged DNS transaction ID was `0x0000`; node2's later upstream query used `0x3ff4`. The legitimate upstream reply arrived at 91.651906537 s, and node2 returned the legitimate negative SOA response to node3. This capture demonstrates that the forged packet reached node2, but it does **not** show successful DNS cache poisoning: it arrived before the relevant upstream query existed and did not match that query's transaction ID.

## Evidence

- [Both-node overview of the Python exchange](../screenshots/23-task3-successful-python-query-both-nodes.png)
- [Python query command and transaction ID](../screenshots/24-task3-python-query-command.png)
- [Returned A and NS records](../screenshots/25-task3-python-response-answer.png)
- [Query IP, UDP, and DNS details on both nodes](../screenshots/26-task3-query-details-both-nodes.png)
- [Response IP, UDP, and DNS details on both nodes](../screenshots/27-task3-response-details-both-nodes.png)
- [Forged-response IP and UDP details](../screenshots/10-task3-forged-response-ip-udp.png)
- [Forged-response DNS fields and timing](../screenshots/11-task3-forged-response-dns-timing.png)
