# Task 5 — AI-Assisted Detection of DNS Attacks

I used AI assistance to develop [`dns_attack_detector.py`](../scripts/dns_attack_detector.py), a passive real-time detector running on node2's `eth0`. I then ran the instructor's `attack.py` from node3 with `num_responses = 50`.

The detector watches node2's upstream DNS queries and replies to its fixed UDP port `12345`. For each query name, it counts replies and distinct DNS transaction IDs within a two-second window. It alerts when at least five distinct IDs arrive in replies that do not match an observed upstream query. When a query has been seen, it also compares each reply's source IP and transaction ID with that query.

For `ijjgi.example.com`, node2 received 50 forged replies from `108.162.195.228` advertising `66.66.66.66` and `ns.attackerpage.com`. The detector alerted after five distinct transaction IDs and later reported **50 replies, 50 distinct IDs, and 50 unmatched replies**. A rapid burst of different IDs for the same name is characteristic of a DNS response-guessing attempt; the short time window and five-ID threshold avoid alerting on a single stray reply. The screenshot shows `expected upstream server(s): not seen`, so this run demonstrates **burst detection**; it does not establish an upstream source-IP mismatch or successful cache poisoning.

The design worked for this lab run because it raised an alert while the forged traffic was being captured. It only reports suspicious traffic; it does not block packets. Further normal-traffic testing would be needed to measure false positives.

AI helped draft the packet-monitoring code and detection rule. Checking the alert against Wireshark was essential: `not seen` means the detector had not observed the upstream query at alert time, so the strongest conclusion from this run is the transaction-ID burst.

## Evidence

- [Detector alert beside forged DNS replies](../screenshots/21-task5-detector-and-forged-replies.png)
- [Detector alert beside the query-name-filtered capture](../screenshots/22-task5-detector-and-query-name.png)
