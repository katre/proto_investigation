#!/usr/bin/env python3
"""Counts spawns in a --execution_log_json_file log by (mnemonic, repo).

Usage: exec_log_summary.py <exec_log.json> [title]
"""
import collections
import json
import re
import sys


def main():
    path = sys.argv[1]
    title = sys.argv[2] if len(sys.argv) > 2 else path
    with open(path) as f:
        text = f.read()
    dec = json.JSONDecoder()
    i, counts = 0, collections.Counter()
    while True:
        while i < len(text) and text[i].isspace():
            i += 1
        if i >= len(text):
            break
        obj, i = dec.raw_decode(text, i)
        m = re.match(r"@@?([^/]*)//", obj.get("targetLabel", ""))
        counts[(obj.get("mnemonic", "?"), m.group(1) or "(main)" if m else "(main)")] += 1
    print(f"# Executed spawns: {title}\n")
    print(f"total spawns: {sum(counts.values())}\n")
    print("| mnemonic | repo | count |")
    print("|---|---|---|")
    for (mn, repo), n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"| {mn} | {repo} | {n} |")


if __name__ == "__main__":
    main()
