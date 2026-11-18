#!/usr/bin/env python3
"""Small DNS relay for the campus network.

Listens on node2's campus address (10.11.2.6:53) and forwards DNS queries to
Docker's embedded resolver on node2 (127.0.0.11:53).  node2 is attached to the
non-internal outside network, so its embedded resolver can reach the VM's
normal upstream DNS.  campus clients therefore use the campus gateway as DNS,
which keeps their campus network intentionally isolated from Docker's host
bridge while still allowing real Internet name resolution through node2.
"""

import socket
import struct
import threading
import sys

LISTEN_IP = "10.11.2.6"
PORT = 53
UPSTREAM = ("127.0.0.11", 53)
TIMEOUT = 4.0


def recv_exact(sock, n):
    data = b""
    while len(data) < n:
        chunk = sock.recv(n - len(data))
        if not chunk:
            raise ConnectionError("unexpected EOF")
        data += chunk
    return data


def handle_udp(data, client, server_sock):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as upstream:
            upstream.settimeout(TIMEOUT)
            upstream.sendto(data, UPSTREAM)
            reply, _ = upstream.recvfrom(65535)
        server_sock.sendto(reply, client)
    except Exception as exc:
        print(f"[dns-proxy] UDP error for {client}: {exc}", file=sys.stderr, flush=True)


def udp_server():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((LISTEN_IP, PORT))
    print(f"[dns-proxy] UDP listening on {LISTEN_IP}:{PORT}", flush=True)
    while True:
        data, client = sock.recvfrom(65535)
        threading.Thread(target=handle_udp, args=(data, client, sock), daemon=True).start()


def handle_tcp(client_sock, client_addr):
    try:
        with client_sock:
            hdr = recv_exact(client_sock, 2)
            length = struct.unpack("!H", hdr)[0]
            query = recv_exact(client_sock, length)
            with socket.create_connection(UPSTREAM, timeout=TIMEOUT) as upstream:
                upstream.sendall(hdr + query)
                rhdr = recv_exact(upstream, 2)
                rlen = struct.unpack("!H", rhdr)[0]
                reply = recv_exact(upstream, rlen)
            client_sock.sendall(rhdr + reply)
    except Exception as exc:
        print(f"[dns-proxy] TCP error for {client_addr}: {exc}", file=sys.stderr, flush=True)


def tcp_server():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((LISTEN_IP, PORT))
    sock.listen(32)
    print(f"[dns-proxy] TCP listening on {LISTEN_IP}:{PORT}", flush=True)
    while True:
        client, addr = sock.accept()
        threading.Thread(target=handle_tcp, args=(client, addr), daemon=True).start()


if __name__ == "__main__":
    t = threading.Thread(target=udp_server, daemon=True)
    t.start()
    tcp_server()
