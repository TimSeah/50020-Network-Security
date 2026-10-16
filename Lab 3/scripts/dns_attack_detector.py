#!/usr/bin/env python3
"""Detect bursts of forged DNS replies at the lab's recursive resolver (node2)."""

from collections import defaultdict, deque
from datetime import datetime


RESOLVER_IP = "10.11.2.6"
UPSTREAM_PORT = 12345
WINDOW_SECONDS = 2.0
ALERT_THRESHOLD = 5


class DNSAttackDetector:
    def __init__(self):
        # qname -> recent (time, upstream server IP, query TXID) tuples
        self.queries = defaultdict(deque)
        # qname -> recent (time, reply TXID, reply source IP, matched query) tuples
        self.replies = defaultdict(deque)
        self.alerted = set()

    def observe_query(self, when, qname, server_ip, txid):
        pending = self.queries[qname]
        pending.append((when, server_ip, txid))
        while pending and when - pending[0][0] > 10:
            pending.popleft()
        print(f"[QUERY] {qname} -> {server_ip}:53 txid=0x{txid:04x}", flush=True)

    def observe_reply(self, when, qname, source_ip, txid):
        pending = self.queries[qname]
        while pending and when - pending[0][0] > 10:
            pending.popleft()
        matched = any(server_ip == source_ip and query_id == txid
                      for _, server_ip, query_id in pending)

        recent = self.replies[qname]
        recent.append((when, txid, source_ip, matched))
        while recent and when - recent[0][0] > WINDOW_SECONDS:
            recent.popleft()

        distinct_ids = len({reply_id for _, reply_id, _, _ in recent})
        unmatched = sum(not is_match for _, _, _, is_match in recent)
        if distinct_ids >= ALERT_THRESHOLD and unmatched >= ALERT_THRESHOLD:
            if qname not in self.alerted:
                expected = ",".join(sorted({server_ip for _, server_ip, _ in pending})) or "not seen"
                sources = ",".join(sorted({ip for _, _, ip, _ in recent}))
                stamp = datetime.fromtimestamp(when).strftime("%H:%M:%S")
                print(
                    f"\n[ALERT {stamp}] Possible Kaminsky attack on {qname}\n"
                    f"  {len(recent)} replies, {distinct_ids} distinct TXIDs in {WINDOW_SECONDS:g}s; "
                    f"{unmatched} did not match an observed query\n"
                    f"  reply source(s): {sources}; expected upstream server(s): {expected}\n",
                    flush=True,
                )
                self.alerted.add(qname)
            elif len(recent) in (20, 50, 200):
                print(
                    f"[UPDATE] {qname}: {len(recent)} replies, "
                    f"{distinct_ids} distinct TXIDs, {unmatched} unmatched",
                    flush=True,
                )


def main():
    from scapy.all import DNS, IP, UDP, sniff

    detector = DNSAttackDetector()

    def handle(packet):
        if not (packet.haslayer(IP) and packet.haslayer(UDP) and packet.haslayer(DNS)):
            return
        ip, udp, dns = packet[IP], packet[UDP], packet[DNS]
        if not dns.qd:
            return
        qname = bytes(dns.qd.qname).decode("ascii", errors="replace").rstrip(".").lower()
        when = float(packet.time)

        if (ip.src == RESOLVER_IP and udp.sport == UPSTREAM_PORT
                and udp.dport == 53 and dns.qr == 0):
            detector.observe_query(when, qname, ip.dst, int(dns.id))
        elif (ip.dst == RESOLVER_IP and udp.sport == 53
              and udp.dport == UPSTREAM_PORT and dns.qr == 1):
            detector.observe_reply(when, qname, ip.src, int(dns.id))

    print(
        f"Monitoring node2 eth0 for DNS replies to {RESOLVER_IP}:{UPSTREAM_PORT}. "
        "Press Ctrl+C to stop.",
        flush=True,
    )
    try:
        sniff(iface="eth0", filter="udp port 53", prn=handle, store=False)
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
