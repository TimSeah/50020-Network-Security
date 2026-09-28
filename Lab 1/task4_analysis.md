# Task 4: AI-Based Traffic Analysis

## Conclusion

The capture shows a monitoring-telemetry injection attack. Host `10.0.2.8` (MAC `08:00:27:25:f3:ec`, identified via ARP) spoofed trusted workstation `10.0.2.6` (`workstation01`) and injected 800 forged messages into node2's monitoring service: first a burst of compromise events, then a flood of false "all clear" status reports.

The capture alone proves the forged telemetry was received by node2. It does not, by itself, prove that every endpoint action named in the forged messages actually occurred on workstation01.

## Features Extracted

I used `analyze_incident.py` with Scapy to read the PCAPNG and export packet features to `incident_packets.csv`. The extracted fields were:

- Packet number and timestamp: establish the incident timeline and traffic rate.
- Ethernet source and destination MAC addresses: identify the device that physically transmitted each frame on the observed network.
- IP source and destination addresses: identify the claimed network-layer identity.
- Protocol, UDP source and destination ports, and payload length: identify the monitored service and compare flows.
- UDP payload preview: inspect the syslog-like telemetry, including host name, sequence number, severity, event, and status.
- IP TTL, identification, frame length, and TCP/ICMP fields where present: useful supporting features for detecting abnormal packet construction or protocol behaviour.

These features are relevant because an IP address is only a claim made in an individual packet. Comparing it with the observed Ethernet sender and with the normal traffic pattern can reveal source-IP spoofing.

## Method

An AI assistant was used to help create the Scapy feature-extraction script. I independently verified the output using packet counts, flow summaries, source-MAC counts, sequence-number ranges, and payload samples.

The analysis used a rule-based anomaly-detection approach:

1. Establish a baseline for normal `10.0.2.6 -> 10.0.2.7` telemetry.
2. Group packets by IP five-tuple and observed Ethernet source MAC.
3. Flag a source IP that maps to more than one Ethernet source MAC during the same service flow.
4. Compare telemetry sequence numbers, timestamps, event types, and statuses for the two sender identities.

## Evidence

| Observation | Result |
|---|---|
| Total packets | 4,061 |
| Capture duration | 816.043 seconds |
| UDP packets | 4,006 |
| Main telemetry flow | `10.0.2.6:40000 -> 10.0.2.7:5514` |
| Normal sender MAC for `10.0.2.6` | `08:00:27:5a:87:bc` (3,200 packets) |
| Suspicious sender MAC claiming `10.0.2.6` | `08:00:27:25:f3:ec` (800 packets) |
| Normal sequence range | `1` through `3200`, all 3,200 values unique |
| Suspicious sequence range | `602` through `2219`, only 713 unique values across 800 packets; all 713 reuse legitimate numbers, 698 with different content |
| ARP owner of suspicious MAC | `10.0.2.8` |
| IP ID pattern | Legitimate: increasing; suspicious: random |

Both senders used the same claimed source IP, destination IP, UDP source port, and UDP destination port. The different Ethernet source address therefore cannot be explained by a normal change of service or port; it is direct evidence that a second local sender impersonated `10.0.2.6`.

The suspicious traffic begins at approximately `2026-09-06T12:35:59Z`, several minutes after normal telemetry begins. It reuses sequence numbers already used by the normal stream, which is inconsistent with a single well-behaved telemetry sender.

Representative injected messages include:

```text
seq=000603 severity=ALERT event=AUTHORIZED_KEY status=ADDED
seq=000605 severity=WARN  event=SSH_CONFIG status=MODIFIED
seq=000606 severity=WARN  event=AUDIT_CONFIG status=MODIFIED
seq=000608 severity=ALERT event=FIREWALL_POLICY status=DISABLED
```

The suspicious sender produced 123 `FIREWALL_POLICY`, 112 `SYSTEM_HEALTH`, 98 `SECURITY_SCAN`, 76 `AUTH`, 71 `INTEGRITY_CHECK`, 57 `SUDO_ROOT`, 46 `SSH_CONFIG`, 40 `AUTHORIZED_KEY`, and 31 `AUDIT_CONFIG` messages. These are security-sensitive events and are not part of the normal sender's event distribution.

## Attack Reconstruction and Likely Objective

`10.0.2.8` resolved node2's MAC via ARP, then sent UDP messages to node2 with the forged source `10.0.2.6` and the normal telemetry ports (`40000` to `5514`).

1. Phase 1 (about 12:36:00, under 30 seconds): `SUDO_ROOT SUCCESS`, `FIREWALL_POLICY DISABLED`, `SSH_CONFIG MODIFIED`, `AUTHORIZED_KEY ADDED`, and `AUDIT_CONFIG MODIFIED`, all as `user=root`.
2. Phase 2 (about 12:40:00 to 12:41:00): `SYSTEM_HEALTH OK`, `SECURITY_SCAN CLEAN`, `FIREWALL_POLICY ENABLED`, `INTEGRITY_CHECK PASS`, and similar reassuring messages.

The likely objective was to poison the SOC's monitoring record: attribute root access and persistence to the trusted workstation, then bury those alerts under false assurance that everything is operating normally. The capture proves the messages were forged; it does not confirm whether the reported changes occurred on workstation01.

## Limitations and Recommendations

- This server-side capture cannot prove endpoint state. Correlate the telemetry with workstation01's local logs, `authorized_keys`, SSH configuration, firewall rules, and audit configuration.
- Source IP alone is not a reliable identity signal. Monitoring telemetry should use authentication and integrity protection, such as mutually authenticated TLS or signed messages.
- Alert when one IP address appears from multiple source MAC addresses, especially when the same service tuple and overlapping sequence numbers are observed.
- Retain both packet captures and authenticated endpoint logs so that spoofed telemetry can be distinguished from genuine endpoint activity.

## Reproduce the Analysis

```powershell
py -3 "Lab 1\analyze_incident.py" "Lab 1\lab1_incident.pcapng" --output "Lab 1\incident_packets.csv"
```