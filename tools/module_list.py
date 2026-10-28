#!/usr/bin/env python3
"""Flattens `bazel mod graph --output=json` into a sorted list of unique modules.

Usage: module_list.py graph.json [--exclude-builtin]

Prints one `name@version` per line, followed by a count. The root module is
never included. With --exclude-builtin, `bazel_tools` and `local_config_platform`
entries are dropped (their dependencies are still counted).
"""

import json
import sys

BUILTIN = {"bazel_tools", "local_config_platform"}


def walk(node, seen):
    for dep in node.get("dependencies", []) + node.get("indirectDependencies", []):
        seen.add(dep["key"])
        walk(dep, seen)
    for dep in node.get("cycles", []):
        seen.add(dep["key"])


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    exclude_builtin = "--exclude-builtin" in sys.argv
    with open(args[0]) as f:
        graph = json.load(f)
    seen = set()
    walk(graph, seen)
    seen.discard("<root>")
    if exclude_builtin:
        seen = {k for k in seen if k.split("@")[0] not in BUILTIN}
    for key in sorted(seen):
        print(key)
    print(f"# total: {len(seen)}")


if __name__ == "__main__":
    main()
