#!/usr/bin/env python3
"""Concise student-facing view of useful BIND recursive cache RRsets."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

DUMP = Path("/var/cache/bind/cache_dump.db")
KEEP = {"A", "AAAA", "CNAME", "DNAME", "NS", "SOA"}


def normalize_owner(name: str) -> str:
    if name == ".":
        return "."
    return name.rstrip(".") + "."


def main() -> int:
    wanted = sys.argv[1].strip().lower().rstrip(".") if len(sys.argv) > 1 else ""
    try:
        subprocess.run(
            ["rndc", "dumpdb", "-cache"],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        print("Could not dump the BIND cache.", file=sys.stderr)
        return 1

    if not DUMP.exists():
        print("Cache dump is empty.")
        return 0

    last_owner = ""
    shown = 0
    in_cache = False

    for raw in DUMP.read_text(errors="replace").splitlines():
        line = raw.rstrip()
        if "Cache dump of view" in line:
            in_cache = True
            continue
        if in_cache and ("Address database dump" in line or "Bad cache" in line):
            break
        if not in_cache or not line or line.lstrip().startswith((";", "$")):
            continue

        tokens = line.split()
        if len(tokens) < 2:
            continue

        owner = ""
        ttl_index = -1
        if re.fullmatch(r"\d+", tokens[0]):
            owner = last_owner
            ttl_index = 0
        elif len(tokens) > 1 and re.fullmatch(r"\d+", tokens[1]):
            owner = tokens[0]
            last_owner = owner
            ttl_index = 1
        else:
            continue

        if not owner or ttl_index < 0:
            continue

        owner = normalize_owner(owner)
        if wanted and wanted not in owner.lower().rstrip("."):
            continue

        ttl = tokens[ttl_index]
        rest = tokens[ttl_index + 1 :]
        if rest and rest[0] == "IN":
            rest = rest[1:]
        if not rest:
            continue

        rrtype = rest[0]
        rdata = " ".join(rest[1:])

        if rrtype in KEEP:
            print(f"{owner:<40} {ttl:>6}  {rrtype:<6} {rdata}")
            shown += 1
            continue

        if rrtype.startswith("\\-"):
            neg_type = rrtype[2:]
            marker = " ".join(rest)
            if "$NXDOMAIN" in marker or neg_type == "ANY":
                label = "NXDOMAIN"
            else:
                label = f"NODATA({neg_type})"
            print(f"{owner:<40} {ttl:>6}  {label}")
            shown += 1

    if shown == 0:
        if wanted:
            print(f"No matching A/AAAA/CNAME/DNAME/NS/SOA/negative cache entries for {wanted}.")
        else:
            print("No concise cache entries are currently cached.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
