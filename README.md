# Network Security Labs

Coursework for Network Security (50.020).

## Lab 1: Packet Sniffing and Spoofing

- Assignment: `Lab 1/docs/Assignment 1 Packet Sniffing and Spoofing.pdf`
- Packet capture: `Lab 1/lab1_incident.pcapng`
- Lab environment: `Lab 1/lab_setup/`

Run the lab on Kali/Linux with Docker, Docker Compose, and X11 support. On Windows, use WSL or another Linux environment with Docker configured.

## Start

```bash
cd "Lab 1/lab_setup"
./start.sh
```

The lab creates three isolated nodes:

- `node1`: `10.11.2.5`
- `node2`: `10.11.2.6`
- `node3`: `10.11.2.7`

Enter a node with `docksh node1`, `docksh node2`, or `docksh node3`.

## Stop

```bash
./stop.sh
```

See [`Lab 1/lab_setup/README.md`](Lab%201/lab_setup/README.md) for credentials, available tools, and troubleshooting.
