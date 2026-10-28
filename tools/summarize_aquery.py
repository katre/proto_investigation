#!/usr/bin/env python3
"""Summarizes `bazel aquery --output=jsonproto` output as markdown.

Usage: summarize_aquery.py aquery.json[.gz] [title]

Reports:
  * total action count, split into target and exec (tool) configuration
  * per-repo action counts for compile-type mnemonics
  * the executable used by every protoc invocation (GenProto* actions), which
    shows whether protoc is prebuilt or built from source
  * cc_binary targets built from source in protobuf/grpc repos
"""

import collections
import gzip
import json
import sys

COMPILE_MNEMONICS = ["CppCompile", "CppArchive", "CppLink", "Javac", "Turbine", "JavaIjar"]
PROTOC_HINTS = ("protoc", "protoc_minimal")


def load(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as f:
        return json.load(f)


def repo_of(label):
    if label.startswith("@@"):
        return label[2:].split("//")[0] or "_main"
    if label.startswith("@"):
        return label[1:].split("//")[0]
    return "_main"


def main():
    path = sys.argv[1]
    title = sys.argv[2] if len(sys.argv) > 2 else path
    d = load(path)
    targets = {t["id"]: t["label"] for t in d.get("targets", [])}
    rule_classes = {r["id"]: r["name"] for r in d.get("ruleClasses", [])}
    target_kind = {t["id"]: rule_classes.get(t.get("ruleClassId"), "?") for t in d.get("targets", [])}
    configs = {c["id"]: c for c in d.get("configuration", [])}
    actions = d.get("actions", [])

    def cfg(a):
        return "exec" if configs.get(a.get("configurationId"), {}).get("isTool") else "target"

    print(f"### {title}\n")
    by_cfg = collections.Counter(cfg(a) for a in actions)
    print(f"Total actions: **{len(actions)}** (target config: {by_cfg['target']}, exec config: {by_cfg['exec']})\n")

    # Per-repo compile counts.
    table = collections.defaultdict(collections.Counter)
    for a in actions:
        table[(repo_of(targets[a["targetId"]]), cfg(a))][a["mnemonic"]] += 1
    rows = [k for k in table if any(table[k][m] for m in COMPILE_MNEMONICS)]
    rows.sort(key=lambda k: -sum(table[k].values()))
    if rows:
        print("| repo | config | all actions | " + " | ".join(COMPILE_MNEMONICS) + " |")
        print("|---|---|---|" + "---|" * len(COMPILE_MNEMONICS))
        for k in rows:
            c = table[k]
            print(f"| `{k[0]}` | {k[1]} | {sum(c.values())} | " + " | ".join(str(c[m]) for m in COMPILE_MNEMONICS) + " |")
        print()
    else:
        print("No compile actions.\n")

    # protoc invocations.
    protoc = collections.Counter()
    for a in actions:
        args = a.get("arguments") or []
        if a["mnemonic"].startswith("GenProto") or (args and args[0].rsplit("/", 1)[-1] in PROTOC_HINTS):
            protoc[(a["mnemonic"], args[0] if args else "?")] += 1
    if protoc:
        print("protoc invocations (mnemonic, executable):\n")
        for (m, exe), n in sorted(protoc.items()):
            kind = "PREBUILT" if "prebuilt_protoc" in exe else ("FROM SOURCE" if exe.startswith("bazel-out/") else "other")
            print(f"- {n} x `{m}`: `{exe}` ({kind})")
        print()

    # cc_binary targets from the protobuf/grpc family (e.g. protoc, plugins).
    binaries = set()
    for a in actions:
        label = targets[a["targetId"]]
        if target_kind[a["targetId"]] == "cc_binary" and any(r in repo_of(label) for r in ("protobuf", "grpc", "upb")):
            binaries.add((label, cfg(a)))
    if binaries:
        print("cc_binary targets built from source in protobuf/grpc repos:\n")
        for label, c in sorted(binaries):
            print(f"- `{label}` [{c}]")
        print()


if __name__ == "__main__":
    main()
