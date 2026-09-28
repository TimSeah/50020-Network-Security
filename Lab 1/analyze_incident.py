#!/usr/bin/env python3
"""Extract report-ready packet features from the Lab 1 incident capture."""

import argparse
import csv
from collections import Counter, defaultdict
from pathlib import Path

from scapy.all import ARP, Ether, ICMP, IP, TCP, UDP, PcapNgReader


def protocol_name(packet) -> str:
    if ICMP in packet:
        return "ICMP"
    if TCP in packet:
        return "TCP"
    if UDP in packet:
        return "UDP"
    return str(packet[IP].proto) if IP in packet else "non-IP"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("incident_packets.csv"),
        help="CSV file for extracted packet features",
    )
    arguments = parser.parse_args()

    protocols = Counter()
    flows = Counter()
    icmp_flows = Counter()
    udp_flows = Counter()
    source_macs = defaultdict(Counter)
    arp_owners = defaultdict(Counter)
    sender_events = defaultdict(Counter)
    sender_sequences = defaultdict(dict)
    timestamps = []

    with arguments.output.open("w", newline="", encoding="utf-8") as output_file:
        fields = [
            "packet_number",
            "timestamp",
            "ethernet_source",
            "ethernet_destination",
            "ip_source",
            "ip_destination",
            "protocol",
            "ip_ttl",
            "ip_identification",
            "ip_length",
            "icmp_type",
            "icmp_code",
            "icmp_identifier",
            "icmp_sequence",
            "tcp_source_port",
            "tcp_destination_port",
            "tcp_flags",
            "udp_source_port",
            "udp_destination_port",
            "payload_length",
            "payload_preview",
            "frame_length",
        ]
        writer = csv.DictWriter(output_file, fieldnames=fields)
        writer.writeheader()

        for number, packet in enumerate(PcapNgReader(str(arguments.capture)), start=1):
            timestamp = float(packet.time)
            timestamps.append(timestamp)
            protocol = protocol_name(packet)
            ip = packet[IP] if IP in packet else None
            ethernet = packet[Ether] if Ether in packet else None
            icmp = packet[ICMP] if ICMP in packet else None
            tcp = packet[TCP] if TCP in packet else None
            udp = packet[UDP] if UDP in packet else None
            payload = bytes(udp.payload) if udp else b""
            payload_text = payload.decode("utf-8", errors="replace")
            payload_preview = " ".join(payload_text.split())[:120]
            telemetry = dict(
                item.split("=", 1) for item in payload_text.split() if "=" in item
            )

            if ARP in packet:
                arp_owners[packet[ARP].psrc][packet[ARP].hwsrc] += 1
            if ip and ethernet and "event" in telemetry:
                sender = (ip.src, ethernet.src)
                sender_events[sender][f"{telemetry['event']}:{telemetry.get('status')}"] += 1
                sender_sequences[sender].setdefault(
                    telemetry.get("seq"), f"{telemetry['event']}:{telemetry.get('status')}"
                )

            protocols[protocol] += 1
            if ip:
                flows[(ip.src, ip.dst, protocol)] += 1
                if ethernet:
                    source_macs[ip.src][ethernet.src] += 1
            if ip and icmp:
                icmp_flows[(ip.src, ip.dst, icmp.type, icmp.code)] += 1
            if ip and udp and ethernet:
                udp_flows[(
                    ip.src,
                    ip.dst,
                    ethernet.src,
                    udp.sport,
                    udp.dport,
                )] += 1

            writer.writerow(
                {
                    "packet_number": number,
                    "timestamp": f"{timestamp:.6f}",
                    "ethernet_source": ethernet.src if ethernet else "",
                    "ethernet_destination": ethernet.dst if ethernet else "",
                    "ip_source": ip.src if ip else "",
                    "ip_destination": ip.dst if ip else "",
                    "protocol": protocol,
                    "ip_ttl": ip.ttl if ip else "",
                    "ip_identification": ip.id if ip else "",
                    "ip_length": ip.len if ip else "",
                    "icmp_type": icmp.type if icmp else "",
                    "icmp_code": icmp.code if icmp else "",
                    "icmp_identifier": icmp.id if icmp else "",
                    "icmp_sequence": icmp.seq if icmp else "",
                    "tcp_source_port": tcp.sport if tcp else "",
                    "tcp_destination_port": tcp.dport if tcp else "",
                    "tcp_flags": str(tcp.flags) if tcp else "",
                    "udp_source_port": udp.sport if udp else "",
                    "udp_destination_port": udp.dport if udp else "",
                    "payload_length": len(payload),
                    "payload_preview": payload_preview,
                    "frame_length": len(packet),
                }
            )

    print(f"Packets: {sum(protocols.values())}")
    print(f"Capture duration: {max(timestamps) - min(timestamps):.6f} seconds")
    print(f"Protocols: {dict(protocols)}")
    print("Top IP flows:")
    for (source, destination, protocol), count in flows.most_common(10):
        print(f"  {count:>5}  {source} -> {destination}  {protocol}")
    print("ICMP flows:")
    for (source, destination, icmp_type, icmp_code), count in icmp_flows.most_common():
        print(
            f"  {count:>5}  {source} -> {destination}  "
            f"type={icmp_type}, code={icmp_code}"
        )
    print("UDP flows by Ethernet source:")
    for (source, destination, mac, source_port, destination_port), count in udp_flows.most_common(10):
        print(
            f"  {count:>5}  {source}:{source_port} -> {destination}:{destination_port} "
            f"via {mac}"
        )
    print("IP source to observed Ethernet source:")
    for source, macs in sorted(source_macs.items()):
        print(f"  {source}: {dict(macs)}")
    print("ARP sender IP to MAC:")
    for source, macs in sorted(arp_owners.items()):
        print(f"  {source}: {dict(macs)}")
    print("Telemetry by sender (IP, MAC):")
    for (source, mac), events in sender_events.items():
        sequences = [int(value) for value in sender_sequences[(source, mac)] if value]
        print(
            f"  {source} via {mac}: {sum(events.values())} messages, "
            f"seq {min(sequences)}-{max(sequences)}, {len(sequences)} unique"
        )
        for event, count in events.most_common(8):
            print(f"      {count:>5}  {event}")
    senders = list(sender_sequences)
    for index, first in enumerate(senders):
        for second in senders[index + 1:]:
            if first[0] != second[0]:
                continue
            shared = set(sender_sequences[first]) & set(sender_sequences[second])
            conflicting = [
                seq for seq in shared
                if sender_sequences[first][seq] != sender_sequences[second][seq]
            ]
            print(
                f"Sequence reuse for {first[0]}: {len(shared)} shared between "
                f"{first[1]} and {second[1]}, {len(conflicting)} with different content"
            )
    print(f"CSV written to: {arguments.output}")


if __name__ == "__main__":
    main()