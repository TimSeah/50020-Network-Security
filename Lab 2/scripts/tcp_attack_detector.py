#!/usr/bin/env python3
"""Watch the isolated Lab 2 node2 network for the three TCP exercises.

Start this on node2 before opening the SSH/Telnet sessions so it can learn
node1's Ethernet address and the sessions' negotiated TCP options.
"""

import argparse
import time
from collections import deque
from dataclasses import dataclass
from datetime import datetime

from scapy.all import Ether, IP, TCP, sniff


@dataclass
class Flow:
    client_mac: str | None = None
    client_offered_ts: bool = False
    timestamps: bool = False
    established: bool = False
    last_seen: float = 0.0


class Detector:
    def __init__(self, args):
        self.args = args
        self.client_mac = args.client_mac.lower() if args.client_mac else None
        self.flows = {}
        self.pending = {}
        self.syns = deque()
        self.last_alert = {}
        self.last_prune = 0.0

    def alert(self, kind, key, detail, now):
        alert_key = (kind, key)
        if now - self.last_alert.get(alert_key, 0) < self.args.cooldown:
            return
        self.last_alert[alert_key] = now
        stamp = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S%z")
        print(f"[{stamp}] {kind}: {detail}", flush=True)

    def prune(self, now):
        while self.syns and now - self.syns[0][0] > self.args.window:
            self.syns.popleft()
        self.pending = {
            flow: start for flow, start in self.pending.items()
            if now - start <= self.args.pending_seconds
        }
        self.flows = {
            flow: state for flow, state in self.flows.items()
            if now - state.last_seen <= 3600
        }

    def packet(self, pkt):
        if IP not in pkt or TCP not in pkt:
            return
        ip, tcp = pkt[IP], pkt[TCP]
        inbound = ip.dst == self.args.server
        outbound = ip.src == self.args.server
        if not inbound and not outbound:
            return

        now = time.time()
        if now - self.last_prune >= 1.0:
            self.prune(now)
            self.last_prune = now
        flags = int(tcp.flags)
        syn = bool(flags & 0x02)
        ack = bool(flags & 0x10)
        rst = bool(flags & 0x04)
        fin = bool(flags & 0x01)
        mac = pkt[Ether].src.lower() if Ether in pkt else None
        client_ip = ip.src if inbound else ip.dst
        client_port = int(tcp.sport if inbound else tcp.dport)
        server_port = int(tcp.dport if inbound else tcp.sport)
        flow = (client_ip, client_port, server_port)
        state = self.flows.get(flow)

        if inbound and syn and not ack:
            self.syns.append((now, client_ip))
            if len(self.syns) > 10000:
                self.syns.popleft()
            if len(self.pending) < 10000:
                self.pending[flow] = now
            if client_ip == self.args.client and server_port in (22, 23):
                state = Flow(client_mac=mac, client_offered_ts=has_ts(tcp), last_seen=now)
                self.flows[flow] = state
            if client_ip == self.args.client and mac and self.client_mac is None:
                self.client_mac = mac
                print(f"Learned {client_ip} Ethernet address {mac} from SYN", flush=True)

            count = len(self.syns)
            if (
                (count >= self.args.syn_threshold or len(self.pending) >= self.args.pending_threshold)
                and now - self.last_alert.get(("SYN FLOOD", "global"), 0) >= self.args.cooldown
            ):
                unique = len({src for _, src in self.syns})
                self.alert(
                    "SYN FLOOD", "global",
                    f"{count} SYNs in {self.args.window:g}s, {unique} source IPs, "
                    f"{len(self.pending)} incomplete handshakes; latest destination port {server_port}",
                    now,
                )
            return

        if state is not None:
            state.last_seen = now
        if outbound and syn and ack and state is not None:
            state.timestamps = state.client_offered_ts and has_ts(tcp)
        if inbound and ack and not syn and flow in self.pending:
            # Only the client's final handshake ACK should complete a pending SYN.
            if state is not None and not state.established and len(bytes(tcp.payload)) == 0:
                state.established = True
                self.pending.pop(flow, None)
        if rst or fin:
            self.pending.pop(flow, None)

        if not inbound:
            return

        expected_mac = self.client_mac if client_ip == self.args.client else None
        if expected_mac is None and state is not None:
            expected_mac = state.client_mac
        mac_mismatch = bool(mac and expected_mac and mac != expected_mac)
        missing_ts = bool(state and state.timestamps and not has_ts(tcp))
        reasons = []
        if mac_mismatch:
            reasons.append(f"Ethernet source {mac} differs from expected {expected_mac}")
        if missing_ts:
            reasons.append("TCP timestamp missing from timestamp-enabled flow")

        if server_port == 22 and rst:
            label = "SUSPICIOUS SSH RST" if reasons else "SSH RST OBSERVED"
            detail = f"{client_ip}:{client_port} -> {ip.dst}:22"
            if reasons:
                detail += "; " + "; ".join(reasons)
            elif state is None or not state.established:
                detail += "; no established-flow baseline (possible normal reset)"
            else:
                detail += "; verify whether this was an expected session close"
            self.alert(label, flow, detail, now)

        if server_port == 23 and len(bytes(tcp.payload)):
            payload = bytes(tcp.payload)
            markers = []
            if b"touch /root/log.txt" in payload:
                markers.append("lab file-creation command")
            if b"/dev/tcp/" in payload or b"nc -e " in payload:
                markers.append("shell redirection command")
            if reasons or markers:
                detail = (
                    f"{client_ip}:{client_port} -> {ip.dst}:23, "
                    f"{len(payload)} payload bytes"
                )
                if reasons:
                    detail += "; " + "; ".join(reasons)
                if markers:
                    detail += "; matched " + ", ".join(markers)
                self.alert("POSSIBLE TELNET INJECTION", flow, detail, now)


def has_ts(tcp):
    return any(name == "Timestamp" for name, _ in tcp.options)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iface", default="eth0", help="node2 capture interface")
    parser.add_argument("--server", default="10.11.2.6", help="node2 IPv4 address")
    parser.add_argument("--client", default="10.11.2.5", help="node1 IPv4 address")
    parser.add_argument("--client-mac", help="known node1 Ethernet address if capture starts late")
    parser.add_argument("--window", type=float, default=5.0, help="SYN rate window in seconds")
    parser.add_argument("--syn-threshold", type=int, default=20, help="SYN count alert threshold")
    parser.add_argument("--pending-threshold", type=int, default=20, help="incomplete handshake alert threshold")
    parser.add_argument("--pending-seconds", type=float, default=30.0, help="incomplete handshake expiry")
    parser.add_argument("--cooldown", type=float, default=5.0, help="seconds between repeated alerts")
    args = parser.parse_args()
    detector = Detector(args)
    print(
        f"Watching {args.iface} on node2 ({args.server}); start SSH/Telnet sessions now. Ctrl+C stops.",
        flush=True,
    )
    try:
        sniff(iface=args.iface, filter="tcp", store=False, prn=detector.packet)
    except KeyboardInterrupt:
        print("Stopped.")


if __name__ == "__main__":
    main()
