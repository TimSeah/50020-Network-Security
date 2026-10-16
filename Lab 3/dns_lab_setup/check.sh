#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

INTERNET=0
if [[ "${1:-}" == "--internet" ]]; then
    INTERNET=1
elif [[ $# -gt 0 ]]; then
    echo "Usage: ./check.sh [--internet]" >&2
    exit 2
fi

if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    DOCKER=(sudo docker)
else
    echo "FAIL: Docker is not accessible." >&2
    exit 1
fi

PASS=0
FAIL=0
pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf 'FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }
check_cmd() { local desc=$1; shift; if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi; }
dexec() { local c=$1; shift; "${DOCKER[@]}" exec "$c" "$@"; }

all_running=1
for c in node1 node2 node3 node4; do
    if ! "${DOCKER[@]}" inspect -f '{{.State.Running}}' "$c" 2>/dev/null | grep -qx true; then all_running=0; fi
done
[[ $all_running -eq 1 ]] && pass "four containers are running" || fail "four containers are running"

expected=("node1:user:10.11.2.5:user" "node2:localdns:10.11.2.6:localdns" "node3:analyst:10.11.2.7:analyst" "node4:attackerns:10.11.2.8:attackerns")
for item in "${expected[@]}"; do
    IFS=: read -r c host ip account <<< "$item"
    actual_host=$(dexec "$c" hostname 2>/dev/null || true)
    actual_ip=$("${DOCKER[@]}" inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$c" 2>/dev/null || true)
    if [[ "$actual_host" == "$host" && "$actual_ip" == "$ip" ]]; then pass "$c hostname/IP"; else fail "$c hostname/IP"; fi
    check_cmd "$c normal account exists" dexec "$c" id "$account"
done

TOOLS=(bash ip ping ifconfig dig named-checkconf named-checkzone tcpdump wireshark tshark curl wget telnet ssh sshd python3 pip3 gedit nano vim sudo ps lsof iptables nft)
tools_ok=1
for c in node1 node2 node3 node4; do
    for t in "${TOOLS[@]}"; do
        if ! dexec "$c" sh -c "command -v '$t' >/dev/null" >/dev/null 2>&1; then
            echo "      missing on $c: $t"
            tools_ok=0
        fi
    done
    if ! dexec "$c" python3 -c 'import scapy.all' >/dev/null 2>&1; then
        echo "      missing on $c: Python Scapy"
        tools_ok=0
    fi
done
[[ $tools_ok -eq 1 ]] && pass "required tools available" || fail "required tools available"

check_cmd "node1 DNS points to node2" dexec node1 grep -Eq '^nameserver[[:space:]]+10\.11\.2\.6$' /etc/resolv.conf
check_cmd "node3 DNS points to node2" dexec node3 grep -Eq '^nameserver[[:space:]]+10\.11\.2\.6$' /etc/resolv.conf
check_cmd "node2 BIND listens on UDP/TCP 53" dexec node2 sh -c "ss -H -lntu | grep -q '10.11.2.6:53'"
check_cmd "node2 recursion is enabled" dexec node2 grep -Eq '^[[:space:]]*recursion[[:space:]]+yes;' /opt/dns-lab/config/node2/named.conf
check_cmd "node2 has no global forwarders" dexec node2 sh -c "! awk '/options[[:space:]]*\{/,/^\};/' /opt/dns-lab/config/node2/named.conf | grep -Eq '^[[:space:]]*forwarders[[:space:]]*\{'"
check_cmd "node2 does not override example.com" dexec node2 sh -c "! grep -Eq 'zone[[:space:]]+\"example\.com\"' /opt/dns-lab/config/node2/named.conf"
check_cmd "node2 UDP query-source port is 12345" dexec node2 grep -Eq 'query-source[[:space:]].*port[[:space:]]+12345;' /opt/dns-lab/config/node2/named.conf
check_cmd "node4 authoritative BIND listens on 53" dexec node4 sh -c "ss -H -lntu | grep -q '10.11.2.8:53'"
check_cmd "node4 web server listens on 80" dexec node4 sh -c "ss -H -lnt | grep -Eq '(:|\\])80[[:space:]]'"

if [[ "$(dexec node1 dig +time=2 +tries=1 +short attackerpage.com A 2>/dev/null | tail -1)" == "10.11.2.8" ]]; then
    pass "attackerpage.com resolves through node2"
else
    fail "attackerpage.com resolves through node2"
fi

if [[ "$(dexec node1 dig +time=2 +tries=1 +short @10.11.2.8 example.com A 2>/dev/null | tail -1)" == "10.11.2.8" ]]; then
    pass "node4 is authoritative for its lab copy of example.com"
else
    fail "node4 is authoritative for its lab copy of example.com"
fi

if [[ "$(dexec node1 dig +time=2 +tries=1 +short @ns.attackerpage.com example.com A 2>/dev/null | tail -1)" == "10.11.2.8" ]]; then
    pass "direct @ns.attackerpage.com query returns lab example.com"
else
    fail "direct @ns.attackerpage.com query returns lab example.com"
fi

if dexec node1 dig +time=2 +tries=1 @10.11.2.8 example.com NS 2>/dev/null | grep -Eq 'example\.com\..*NS[[:space:]]+ns\.attackerpage\.com\.'; then
    pass "example.com NS points to ns.attackerpage.com"
else
    fail "example.com NS points to ns.attackerpage.com"
fi

check_cmd "node2 rndc key exists" dexec node2 sh -c "test -r /etc/bind/rndc.key"
check_cmd "node2 control channel listens on TCP 953" dexec node2 sh -c "ss -H -lnt 2>/dev/null | grep -Eq '127\.0\.0\.1:953'"
check_cmd "rndc works on node2" dexec node2 rndc status
if [[ "$(dexec node2 flushcache 2>/dev/null)" == "Flushed." ]]; then pass "flushcache works"; else fail "flushcache works"; fi
check_cmd "node4 example.com operator zone file is in /etc/bind" dexec node4 sh -c "test -r /etc/bind/db.example.com"
check_cmd "node4 zone reload helper is available" dexec node4 sh -c "command -v reloadzone >/dev/null && rndc status >/dev/null"
check_cmd "dumpcap can see eth0" dexec node2 sh -c "dumpcap -D 2>/dev/null | grep -q 'eth0'"

if [[ $INTERNET -eq 1 ]]; then
    echo
    echo "Direct-recursion Internet check:"
    tmp=$(mktemp)
    if dexec node1 dig +time=8 +tries=1 example.com A >"$tmp" 2>&1 && grep -q 'status: NOERROR' "$tmp"; then
        if grep -Eq 'example\.com\..*[[:space:]]A[[:space:]]+10\.11\.2\.8([[:space:]]|$)' "$tmp"; then
            fail "normal example.com unexpectedly returned the lab node4 address"
        else
            pass "normal example.com is resolved from the real public DNS hierarchy"
        fi
    else
        root_out=$(dexec node2 dig +time=4 +tries=1 +norecurse @198.41.0.4 . NS 2>/dev/null || true)
        if grep -q 'status: NOERROR' <<< "$root_out"; then
            fail "root DNS is reachable, but BIND recursion failed (inspect node2 logs and network policy for UDP source port 12345)"
        else
            fail "direct DNS from the container to Internet root servers is blocked/unavailable; this network cannot support full external recursion"
        fi
    fi
    rm -f "$tmp"
fi

echo
printf 'Summary: %d passed, %d failed.\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
