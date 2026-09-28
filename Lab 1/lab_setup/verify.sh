#!/usr/bin/env bash
set -uo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

nodes=(lab-node1 lab-node2 lab-node3)

declare -A expected_ip=(
    [lab-node1]="10.11.2.5"
    [lab-node2]="10.11.2.6"
    [lab-node3]="10.11.2.7"
)

failed=0

ok() { printf '[ OK ] %s\n' "$*"; }
bad() { printf '[FAIL] %s\n' "$*" >&2; failed=1; }

echo "=== Container status ==="
for n in "${nodes[@]}"; do
    [[ "$(docker inspect -f '{{.State.Running}}' "$n" 2>/dev/null || true)" == "true" ]] \
        && ok "$n running" \
        || bad "$n not running"
done

echo
echo "=== Fixed IPv4 addresses ==="
for n in "${nodes[@]}"; do
    ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$n" 2>/dev/null || true)"
    [[ "$ip" == "${expected_ip[$n]}" ]] \
        && ok "$n IP=$ip" \
        || bad "$n expected ${expected_ip[$n]}, got '$ip'"
done

echo
echo "=== Isolated Docker network ==="
if docker network inspect three-node-tcp-lab-net >/dev/null 2>&1; then
    internal="$(docker network inspect three-node-tcp-lab-net --format '{{.Internal}}')"
    subnet="$(docker network inspect three-node-tcp-lab-net --format '{{(index .IPAM.Config 0).Subnet}}')"
    [[ "$internal" == "true" ]] && ok "Internal=true" || bad "Internal=$internal"
    [[ "$subnet" == "10.11.2.0/24" ]] && ok "Subnet=$subnet" || bad "Subnet=$subnet"
else
    bad "three-node-tcp-lab-net missing"
fi

echo
echo "=== Default TCP sysctls ==="
for n in "${nodes[@]}"; do
    syncookies="$(docker exec "$n" sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || true)"
    retries="$(docker exec "$n" sysctl -n net.ipv4.tcp_synack_retries 2>/dev/null || true)"
    backlog="$(docker exec "$n" sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null || true)"

    [[ "$syncookies" == "0" ]] && ok "$n tcp_syncookies=0" || bad "$n tcp_syncookies=$syncookies"
    [[ "$retries" == "5" ]] && ok "$n tcp_synack_retries=5" || bad "$n tcp_synack_retries=$retries"
    [[ "$backlog" == "128" ]] && ok "$n tcp_max_syn_backlog=128" || bad "$n tcp_max_syn_backlog=$backlog"
done

echo
echo "=== Random-source return-path isolation ==="
for n in "${nodes[@]}"; do
    all_rp="$(docker exec "$n" sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null || true)"
    eth_rp="$(docker exec "$n" sysctl -n net.ipv4.conf.eth0.rp_filter 2>/dev/null || true)"

    # 0 = disabled, 1 = strict, 2 = loose.
    # This lab accepts 0 or 2. Strict mode 1 is not suitable because the
    # reverse path for arbitrary spoofed sources is intentionally sink0.
    case "$all_rp" in
        0) ok "$n all.rp_filter=0 (disabled)" ;;
        2) ok "$n all.rp_filter=2 (loose; compatible with sink0)" ;;
        *) bad "$n all.rp_filter=$all_rp (strict/unsupported)" ;;
    esac

    case "$eth_rp" in
        0) ok "$n eth0.rp_filter=0 (disabled)" ;;
        2) ok "$n eth0.rp_filter=2 (loose; compatible with sink0)" ;;
        *) bad "$n eth0.rp_filter=$eth_rp (strict/unsupported)" ;;
    esac

    docker exec "$n" ip link show sink0 >/dev/null 2>&1 \
        && ok "$n sink0 exists" \
        || bad "$n sink0 missing"

    local_route="$(docker exec "$n" ip route get 10.11.2.100 2>/dev/null || true)"
    random_route="$(docker exec "$n" ip route get 198.51.100.77 2>/dev/null || true)"

    echo "$local_route" | grep -q 'dev eth0' \
        && ok "$n lab subnet -> eth0" \
        || bad "$n lab route: $local_route"

    echo "$random_route" | grep -q 'dev sink0' \
        && ok "$n arbitrary unicast -> sink0" \
        || bad "$n sink route: $random_route"
done

echo
echo "=== Functional arbitrary-source SYN test ==="
TEST_SRC="198.51.100.77"
TEST_SPORT="45678"
TEST_SEQ="305419896"

docker exec lab-node3 python3 -c "
from scapy.all import IP, TCP, send
send(
    IP(src='${TEST_SRC}', dst='10.11.2.6') /
    TCP(sport=${TEST_SPORT}, dport=23, flags='S', seq=${TEST_SEQ}),
    verbose=False
)
" >/dev/null 2>&1

sleep 0.2

if docker exec lab-node2 ss -Hnt state syn-recv 2>/dev/null \
    | grep -Eq "${TEST_SRC}:${TEST_SPORT}([[:space:]]|$)"; then
    ok "node2 accepted arbitrary-source SYN into SYN-RECV"
else
    bad "node2 did not place arbitrary-source SYN into SYN-RECV"
fi

# Best-effort cleanup of the verification half-open connection.
docker exec lab-node3 python3 -c "
from scapy.all import IP, TCP, send
send(
    IP(src='${TEST_SRC}', dst='10.11.2.6') /
    TCP(sport=${TEST_SPORT}, dport=23, flags='R', seq=${TEST_SEQ}+1),
    verbose=False
)
" >/dev/null 2>&1 || true

echo
echo "=== TCP sysctls writable ==="
orig_sync="$(docker exec lab-node1 sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || true)"
orig_retry="$(docker exec lab-node1 sysctl -n net.ipv4.tcp_synack_retries 2>/dev/null || true)"
orig_backlog="$(docker exec lab-node1 sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null || true)"

docker exec lab-node1 sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null 2>&1 \
    && ok "tcp_syncookies writable" || bad "tcp_syncookies not writable"
docker exec lab-node1 sysctl -w net.ipv4.tcp_synack_retries=4 >/dev/null 2>&1 \
    && ok "tcp_synack_retries writable" || bad "tcp_synack_retries not writable"
docker exec lab-node1 sysctl -w net.ipv4.tcp_max_syn_backlog=256 >/dev/null 2>&1 \
    && ok "tcp_max_syn_backlog writable" || bad "tcp_max_syn_backlog not writable"

docker exec lab-node1 sysctl -w "net.ipv4.tcp_syncookies=${orig_sync:-0}" >/dev/null 2>&1 || true
docker exec lab-node1 sysctl -w "net.ipv4.tcp_synack_retries=${orig_retry:-5}" >/dev/null 2>&1 || true
docker exec lab-node1 sysctl -w "net.ipv4.tcp_max_syn_backlog=${orig_backlog:-128}" >/dev/null 2>&1 || true

echo
echo "=== Interactive sysctl write test on every node ==="
for n in "${nodes[@]}"; do
    orig_sync="$(docker exec "$n" sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || true)"
    orig_retry="$(docker exec "$n" sysctl -n net.ipv4.tcp_synack_retries 2>/dev/null || true)"
    orig_backlog="$(docker exec "$n" sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null || true)"

    write_ok=1

    docker exec "$n" sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null 2>&1 || write_ok=0
    [[ "$(docker exec "$n" sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || true)" == "1" ]] || write_ok=0

    docker exec "$n" sysctl -w net.ipv4.tcp_synack_retries=4 >/dev/null 2>&1 || write_ok=0
    [[ "$(docker exec "$n" sysctl -n net.ipv4.tcp_synack_retries 2>/dev/null || true)" == "4" ]] || write_ok=0

    docker exec "$n" sysctl -w net.ipv4.tcp_max_syn_backlog=50 >/dev/null 2>&1 || write_ok=0
    [[ "$(docker exec "$n" sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null || true)" == "50" ]] || write_ok=0

    # Restore original/default values immediately.
    docker exec "$n" sysctl -w "net.ipv4.tcp_syncookies=${orig_sync:-0}" >/dev/null 2>&1 || true
    docker exec "$n" sysctl -w "net.ipv4.tcp_synack_retries=${orig_retry:-5}" >/dev/null 2>&1 || true
    docker exec "$n" sysctl -w "net.ipv4.tcp_max_syn_backlog=${orig_backlog:-128}" >/dev/null 2>&1 || true

    if [[ "$write_ok" -eq 1 ]]; then
        ok "$n interactive sysctl -w persists"
    else
        bad "$n interactive sysctl -w failed"
    fi
done

echo
echo "=== Required commands ==="
for n in "${nodes[@]}"; do
    for cmd in python3 wireshark gedit tshark tcpdump ssh telnet nc ip ss ping netstat ps sysctl; do
        if docker exec "$n" sh -c "command -v '$cmd' >/dev/null 2>&1"; then
            ok "$n $cmd"
        else
            bad "$n missing $cmd"
        fi
    done
done

echo
echo "=== Netcat smoke test ==="
NC_PORT="46666"
NC_MARKER="netcat-ok-$RANDOM-$$"
docker exec lab-node2 rm -f /tmp/netcat-verify.txt >/dev/null 2>&1 || true
docker exec -d lab-node2 sh -c \
    "timeout 5 nc -l -n -p ${NC_PORT} > /tmp/netcat-verify.txt"
sleep 0.3

if printf '%s\n' "$NC_MARKER" \
    | docker exec -i lab-node1 nc -n -w 2 10.11.2.6 "$NC_PORT" >/dev/null 2>&1; then
    sleep 0.2
    if docker exec lab-node2 grep -qx "$NC_MARKER" /tmp/netcat-verify.txt 2>/dev/null; then
        ok "node1 -> node2 netcat TCP listener/client"
    else
        bad "netcat connected but payload verification failed"
    fi
else
    bad "node1 could not connect to node2 with netcat"
fi
docker exec lab-node2 rm -f /tmp/netcat-verify.txt >/dev/null 2>&1 || true

echo
echo "=== Python + Scapy imports ==="
SCAPY_TEST='
from scapy.all import IP, TCP, send
from ipaddress import IPv4Address
from random import getrandbits
from scapy.all import *
assert str(IPv4Address(0x0A0B0205)) == "10.11.2.5"
assert isinstance(IP(dst="10.11.2.6")/TCP(dport=23), Packet)
'

for n in "${nodes[@]}"; do
    docker exec "$n" python3 -c "$SCAPY_TEST" >/dev/null 2>&1 \
        && ok "$n Python/Scapy imports" \
        || bad "$n Python/Scapy imports"
done

echo
echo "=== Packet capture permission ==="
for n in "${nodes[@]}"; do
    docker exec --user kali "$n" dumpcap -D >/dev/null 2>&1 \
        && ok "$n dumpcap as kali" \
        || bad "$n dumpcap as kali"
done

echo
echo "=== Inter-container ping ==="
docker exec lab-node1 ping -c 1 -W 1 10.11.2.6 >/dev/null 2>&1 \
    && ok "node1 -> node2" || bad "node1 -> node2"
docker exec lab-node1 ping -c 1 -W 1 10.11.2.7 >/dev/null 2>&1 \
    && ok "node1 -> node3" || bad "node1 -> node3"
docker exec lab-node2 ping -c 1 -W 1 10.11.2.5 >/dev/null 2>&1 \
    && ok "node2 -> node1" || bad "node2 -> node1"

echo
echo "=== SSH / Telnet listeners ==="
for n in "${nodes[@]}"; do
    docker exec "$n" sh -c "ss -lnt | grep -Eq '[:.]22[[:space:]]'" \
        && ok "$n SSH TCP/22 listening" \
        || bad "$n SSH TCP/22 not listening"

    docker exec "$n" sh -c "ss -lnt | grep -Eq '[:.]23[[:space:]]'" \
        && ok "$n Telnet TCP/23 listening" \
        || bad "$n Telnet TCP/23 not listening"
done

echo
echo "=== Shared folder ==="
testfile="verify-$RANDOM-$$.txt"
printf 'shared-folder-test\n' | docker exec -i lab-node1 sh -c "cat > /shared/$testfile"

shared_ok=1
docker exec lab-node2 grep -q "shared-folder-test" "/shared/$testfile" || shared_ok=0
docker exec lab-node3 grep -q "shared-folder-test" "/shared/$testfile" || shared_ok=0
grep -q "shared-folder-test" "shared/$testfile" 2>/dev/null || shared_ok=0

[[ "$shared_ok" -eq 1 ]] \
    && ok "/shared visible from host + all 3 nodes" \
    || bad "/shared verification"

rm -f "shared/$testfile"

echo
if [[ "$failed" -eq 0 ]]; then
    echo "ALL CHECKS PASSED."
    exit 0
else
    echo "ONE OR MORE CHECKS FAILED." >&2
    exit 1
fi
