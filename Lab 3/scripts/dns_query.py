import argparse
import secrets
import socket

from scapy.layers.dns import DNS, DNSQR


def build_query(name):
    return DNS(
        id=secrets.randbelow(65536),
        qr=0,
        opcode=0,
        rd=1,
        qd=DNSQR(qname=name, qtype="A", qclass="IN"),
    )


def main():
    parser = argparse.ArgumentParser(description="Send an A query to the lab DNS resolver.")
    parser.add_argument("name", nargs="?", default="example.com")
    parser.add_argument("--server", default="10.11.2.6")
    parser.add_argument("--timeout", type=float, default=15.0)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")

    query = build_query(args.name)
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
            client.settimeout(args.timeout)
            client.connect((args.server, 53))
            source_ip, source_port = client.getsockname()
            print(f"Query: {source_ip}:{source_port} -> {args.server}:53")
            print(f"Transaction ID: 0x{query.id:04x}")
            query.show()
            client.send(bytes(query))
            payload = client.recv(65535)
    except OSError as error:
        print(f"DNS exchange failed: {error}")
        return 1

    response = DNS(payload)
    if (
        response.id != query.id
        or response.qr != 1
        or response.opcode != query.opcode
        or response.qdcount != 1
        or response.qd.qname.lower() != query.qd.qname.lower()
        or response.qd.qtype != query.qd.qtype
        or response.qd.qclass != query.qd.qclass
    ):
        print("Received a packet that does not match the DNS query.")
        return 1

    print(f"Response: {args.server}:53 -> {source_ip}:{source_port}")
    response.show()
    if response.tc:
        print("Response is truncated; a complete lookup requires retrying over TCP.")
        return 1
    if response.rcode != 0:
        print(f"Resolver returned DNS error code {response.rcode}.")
        return 1
    if response.ancount == 0:
        print("The response contains no answer records.")
        return 1
    print("Received a matching DNS response with answer records.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())