#!/usr/bin/env python3
"""Summarizes supply-chain SBOM outputs as markdown.

Usage: sbom_components.py <dir> [title]

<dir> holds the outputs of the sbom/cyclonedx/spdx rules for one or more
targets (<T>_sbom.graph.json, <T>_sbom.sbom-classifications.json,
<T>_cyclonedx.json, <T>_spdx.json). For each target, prints the graph size,
the repos of the graph nodes, the classified dependencies, and the CycloneDX
and SPDX components (name@version, purl).
"""
import collections
import json
import os
import re
import sys


def load(path):
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return json.load(f)


def repo_of(label):
    m = re.match(r"@@?([^/]*)//", label)
    return m.group(1) if m else "(main)"


def main():
    d = sys.argv[1]
    title = sys.argv[2] if len(sys.argv) > 2 else d
    targets = sorted(f[: -len("_sbom.graph.json")] for f in os.listdir(d)
                     if f.endswith("_sbom.graph.json"))
    print(f"# SBOM components: {title}\n")
    print("| target | graph nodes | graph edges | classified direct | classified transitive "
          "| CycloneDX components | SPDX packages |")
    print("|---|---|---|---|---|---|---|")
    details = []
    for t in targets:
        graph = load(os.path.join(d, f"{t}_sbom.graph.json")) or {}
        cls = load(os.path.join(d, f"{t}_sbom.sbom-classifications.json")) or {}
        cdx = load(os.path.join(d, f"{t}_cyclonedx.json")) or {}
        spdx = load(os.path.join(d, f"{t}_spdx.json")) or {}
        deps = cls.get("dependencies", {})
        comps = ["%s@%s (%s)" % (c.get("name"), c.get("version", "?"), c.get("purl", ""))
                 for c in cdx.get("components", [])]
        pkgs = []
        for p in spdx.get("packages", []):
            purls = [r["referenceLocator"] for r in p.get("externalRefs", [])
                     if r.get("referenceType") == "purl"]
            pkgs.append("%s (%s)" % (p.get("name"), ", ".join(purls)))
        nodes = graph.get("nodes", [])
        edges = graph.get("edges", [])
        print(f"| {t} | {len(nodes)} | {len(edges)} | {len(deps.get('direct', []))} "
              f"| {len(deps.get('transitive', []))} | {len(comps)} | {len(pkgs)} |")
        node_repos = collections.Counter(repo_of(n.get("label", "")) for n in nodes)
        edge_repos = collections.Counter(repo_of(x) for e in edges for x in (e["from"], e["to"]))
        details.append((t, node_repos, edge_repos, comps, pkgs))
    for t, node_repos, edge_repos, comps, pkgs in details:
        print(f"\n## {t}\n")
        print("- graph node repos (targets with metadata): "
              + (", ".join(f"{r} ({n})" for r, n in sorted(node_repos.items())) or "none"))
        print("- graph edge endpoint repos: "
              + (", ".join(sorted(edge_repos)) or "none"))
        print("- CycloneDX components: " + ("; ".join(comps) or "none"))
        print("- SPDX packages: " + ("; ".join(pkgs) or "none"))


if __name__ == "__main__":
    main()
