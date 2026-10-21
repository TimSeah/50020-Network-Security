#!/usr/bin/env python3
"""Simple real-time attack indicator monitor for the Campus Service lab.

Reads Apache's combined access log and reports suspicious request indicators.
This is a teaching aid, not a general-purpose web application firewall.
"""

from __future__ import annotations

import argparse
import html
import os
import re
import sys
import time
from datetime import datetime
from urllib.parse import parse_qsl, unquote_plus, urlsplit


LOG_PATTERN = re.compile(
    r'^(?P<ip>\S+) \S+ \S+ \[(?P<time>[^]]+)\] '
    r'"(?P<request>[^\"]*)" (?P<status>\d{3}|-) (?P<size>\S+) '
    r'"(?P<referer>[^\"]*)" "(?P<agent>[^\"]*)"'
)

SQLI_RULES = (
    ("UNION SELECT", re.compile(r"\bunion\b[\s\W_]*\bselect\b", re.I)),
    ("database metadata enumeration", re.compile(r"information_schema|sqlite_master", re.I)),
    ("database-name function", re.compile(r"\bdatabase\s*\(\s*\)", re.I)),
    ("boolean SQL condition", re.compile(r"(?:['\"]\s*or\s+|\bor\s+)\d+\s*=\s*\d+", re.I)),
    ("stacked data modification", re.compile(r";\s*(?:update|insert|delete|drop|alter)\b", re.I)),
)

XSS_RULES = (
    ("script element", re.compile(r"<\s*/?\s*script\b", re.I)),
    ("HTML event handler", re.compile(r"\bon[a-z]{3,}\s*=", re.I)),
    ("javascript URL", re.compile(r"javascript\s*:", re.I)),
    ("JavaScript alert marker", re.compile(r"\balert\s*\(", re.I)),
)


def repeatedly_decode(value: str) -> str:
    """Decode URL and HTML encodings a few times to expose common obfuscation."""
    current = value
    for _ in range(4):
        decoded = html.unescape(unquote_plus(current))
        if decoded == current:
            break
        current = decoded
    return current


def parse_request(line: str) -> dict[str, str] | None:
    match = LOG_PATTERN.match(line.rstrip("\n"))
    if not match:
        return None
    method, target, _version = (match.group("request").split(" ", 2) + ["", "", ""])[:3]
    parsed = urlsplit(target)
    return {
        "ip": match.group("ip"),
        "time": match.group("time"),
        "method": method,
        "path": parsed.path or "/",
        "query": parsed.query,
        "status": match.group("status"),
        "referer": match.group("referer"),
    }


def inspect(entry: dict[str, str]) -> list[tuple[str, str]]:
    """Return (category, reason) alerts for one parsed access-log line."""
    alerts: list[tuple[str, str]] = []
    request_text = repeatedly_decode(entry["path"] + "?" + entry["query"])

    for reason, pattern in SQLI_RULES:
        if pattern.search(request_text):
            alerts.append(("SQLi indicator", reason))

    for reason, pattern in XSS_RULES:
        if pattern.search(request_text):
            alerts.append(("XSS indicator", reason))

    if entry["path"].rstrip("/").lower() == "/__xss_probe__":
        alerts.append(("XSS execution beacon", "local lab marker request observed"))

    if entry["method"].upper() == "GET" and entry["path"].lower().endswith("/request_action.php"):
        params = dict(parse_qsl(entry["query"], keep_blank_values=True))
        if params.get("decision", "").lower() in {"approve", "reject"}:
            reason = "state-changing decision endpoint was called with GET; potential CSRF"
            ref = entry["referer"]
            if ref and ref != "-":
                ref_host = (urlsplit(ref).hostname or "").lower()
                if ref_host and ref_host not in {"portal.campus.test", "localhost"}:
                    reason += "; referrer is outside the portal host"
            alerts.append(("CSRF risk", reason))

    return alerts


def report(entry: dict[str, str], alerts: list[tuple[str, str]]) -> None:
    """Print useful evidence without dumping the full query string."""
    stamp = entry["time"] or datetime.now().astimezone().strftime("%d/%b/%Y:%H:%M:%S %z")
    for category, reason in alerts:
        print(
            f"[{stamp}] ALERT {category} | {entry['ip']} | "
            f"{entry['method']} {entry['path']} | HTTP {entry['status']} | {reason}",
            flush=True,
        )


def follow(path: str, from_start: bool) -> None:
    """Follow an access log, including common rename-and-reopen rotations."""
    handle = None
    current_inode = None
    print(f"Monitoring {path} (Ctrl+C to stop). Waiting for new requests...", flush=True)
    while True:
        try:
            stat = os.stat(path)
            if handle is None or current_inode != (stat.st_dev, stat.st_ino):
                if handle is not None:
                    handle.close()
                handle = open(path, "r", encoding="utf-8", errors="replace")
                current_inode = (stat.st_dev, stat.st_ino)
                if not from_start:
                    handle.seek(0, os.SEEK_END)
                print(f"Following log file: {path}", flush=True)
            elif stat.st_size < handle.tell():
                handle.seek(0)

            line = handle.readline()
            if not line:
                time.sleep(0.25)
                continue
            entry = parse_request(line)
            if entry is None:
                print("[INFO] Skipped a line that did not match Apache combined format.", flush=True)
                continue
            alerts = inspect(entry)
            if alerts:
                report(entry, alerts)
        except FileNotFoundError:
            print(f"Waiting for log file to appear: {path}", flush=True)
            time.sleep(1)
        except PermissionError:
            print(f"Permission denied reading {path}; try running with sudo.", file=sys.stderr, flush=True)
            raise SystemExit(2)
        except KeyboardInterrupt:
            print("\nStopped.", flush=True)
            return
        except OSError as exc:
            print(f"Log read error: {exc}", file=sys.stderr, flush=True)
            time.sleep(1)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Monitor the Campus Service Apache access log for lab attack indicators."
    )
    parser.add_argument(
        "--log",
        default="/var/log/apache2/campus-portal-access.log",
        help="Apache combined access-log path (default: %(default)s)",
    )
    parser.add_argument(
        "--from-start",
        action="store_true",
        help="scan existing log lines before following new requests",
    )
    args = parser.parse_args()
    try:
        follow(args.log, args.from_start)
    except KeyboardInterrupt:
        print("\nStopped.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
