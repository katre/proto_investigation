#!/bin/bash
# SBOMs (bazel-contrib/supply-chain) for the 01 project (protobuf 37.0-rc1).
# Builds only //sbom:* and the metadata aspects. No protobuf code is compiled.
cd "$(dirname "$0")"
source ../tools/common.sh

TARGETS=(greeting_proto greeting_cc_proto greeting_java_proto greeting_py_proto greeting_cc_bin greeting_java_bin)

# Copies the sbom outputs from bazel-bin into results/$1.
save_sboms() {
  rm -rf "$R/$1"; mkdir -p "$R/$1"
  cp bazel-bin/sbom/*.json "$R/$1/"
  chmod u+w "$R/$1"/*.json
}

record_env

# 1. Show which actions building the SBOMs needs before running them, then
#    run them with an execution log.
"${B[@]}" aquery 'deps(//sbom:all)' --output=jsonproto --include_artifacts=false 2>/dev/null \
  | gzip > "$R/aquery_sbom_all.json.gz"
python3 "$TOOLS/summarize_aquery.py" "$R/aquery_sbom_all.json.gz" "deps(//sbom:all)" \
  > "$R/aquery_sbom_all.md"
"${B[@]}" build //sbom:all --execution_log_json_file="${OUTPUT_BASE}-exec.json" \
  > "$R/build_sbom_all.log" 2>&1
python3 "$TOOLS/exec_log_summary.py" "${OUTPUT_BASE}-exec.json" "bazel build //sbom:all" \
  > "$R/executed_sbom_all.md"
save_sboms sbom
python3 "$TOOLS/sbom_components.py" "$R/sbom" "default (protobuf 37.0-rc1 as published)" \
  > "$R/sbom_components.md"
fetched fetched_after_sbom_build.txt
sizes fetched_sizes_kib.txt

# 2. Cross-check: run the gather_metadata aspect directly on each target.
rm -rf "$R/aspect"; mkdir -p "$R/aspect"
"${B[@]}" build "${TARGETS[@]/#///proto:}" \
  --aspects=@supply_chain_tools//gather_metadata:gather_metadata.bzl%gather_metadata_info_and_write \
  --output_groups=metadata > "$R/build_aspect.log" 2>&1
for t in "${TARGETS[@]}"; do
  cp "bazel-bin/proto/${t}_metadata_info.json" "$R/aspect/"
  if cmp -s "$R/aspect/${t}_metadata_info.json" "$R/sbom/${t}_sbom.graph.json"; then
    echo "$t: aspect output == sbom graph.json"
  else
    echo "$t: aspect output DIFFERS from sbom graph.json"
  fi
done > "$R/aspect_vs_sbom.txt"

# 3. Upper bound: every target-config target the aspect visits (the same
#    traversal rules), whether or not it has metadata.
rm -rf "$R/traversal"; mkdir -p "$R/traversal"
"${B[@]}" build "${TARGETS[@]/#///proto:}" --aspects=//probe:traversal.bzl%sbom_traversal \
  --output_groups=sbom_traversal > "$R/build_traversal.log" 2>&1
for t in "${TARGETS[@]}"; do
  cp "bazel-bin/proto/${t}.sbom_traversal.txt" "$R/traversal/${t}.txt"
done

# 4. Compare against the configured graph: repos with targets in deps(T),
#    split by configuration ("none" means source files).
CFG_EXPR='str(target.label) + " " + ("none" if build_options(target) == None else ("exec" if build_options(target)["//command_line_option:is exec configuration"] else "target"))'
for t in "${TARGETS[@]}"; do
  "${B[@]}" cquery "deps(//proto:$t)" --output=starlark --starlark:expr="$CFG_EXPR" \
    2>/dev/null > "${OUTPUT_BASE}-cquery-$t.txt"
done
python3 - "$R" "${OUTPUT_BASE}-cquery" "${TARGETS[@]}" > "$R/repo_comparison.md" <<'EOF'
import re, sys
r, cq, targets = sys.argv[1], sys.argv[2], sys.argv[3:]
def repo(label):
    m = re.match(r"@@?([^/]*)//", label)
    return (m.group(1) or "(main)") if m else "(main)"
print("# Repos per target: SBOM traversal vs configured graph\n")
print("`traversal` = repos with targets the gather_metadata aspect visits (upper bound for")
print("the SBOM). `cquery target` / `cquery exec` = repos with targets in `deps(T)` by")
print("configuration. Source files (null config) are not counted.\n")
for t in targets:
    trav = sorted({repo(l) for l in open(f"{r}/traversal/{t}.txt").read().split()})
    tgt, exe = set(), set()
    for line in open(f"{cq}-{t}.txt"):
        parts = line.split()
        if len(parts) != 2:
            continue
        (tgt if parts[1] == "target" else exe if parts[1] == "exec" else set()).add(repo(parts[0]))
    print(f"## {t}\n")
    print(f"- traversal ({len(trav)}): {', '.join(trav)}")
    print(f"- cquery target ({len(tgt)}): {', '.join(sorted(tgt))}")
    print(f"- cquery exec only ({len(exe - tgt)}): {', '.join(sorted(exe - tgt))}")
    print(f"- cquery target but not traversed: {', '.join(sorted(tgt - set(trav))) or 'none'}\n")
EOF

# 5. Hypothetical: protobuf declares package_metadata (via REPO.bazel and by
#    turning its rules_license //:license into a package_metadata target).
#    Shows what the SBOMs would contain once protobuf adopts the new metadata.
PB="${OUTPUT_BASE}-metadata-protobuf"
rm -rf "$PB"; cp -rL "${OUTPUT_BASE}/external/protobuf+" "$PB"; chmod -R u+w "$PB"
python3 - "$PB" <<'EOF'
import sys
pb = sys.argv[1]
s = open(f"{pb}/BUILD.bazel").read()
old = '''license(
    name = "license",
    package_name = "protobuf",
    license_text = ":LICENSE",
)'''
assert old in s
s = s.replace(old, '''package_metadata(
    name = "license",
    attributes = [":license_kind"],
    purl = "pkg:bazel/protobuf@37.0-rc1",
    visibility = ["//visibility:public"],
)

pm_license(
    name = "license_kind",
    kind = "@package_metadata//licenses/spdx:BSD-3-Clause",
    text = "LICENSE",
)''')
s = s.replace('load("@rules_license//rules:license.bzl", "license")\n',
              'load("@package_metadata//licenses/rules:license.bzl", pm_license = "license")\n'
              'load("@package_metadata//rules:package_metadata.bzl", "package_metadata")\n')
open(f"{pb}/BUILD.bazel", "w").write(s)
m = open(f"{pb}/MODULE.bazel").read()
m = m.replace('bazel_dep(name = "rules_license", version = "1.0.0")',
              'bazel_dep(name = "rules_license", version = "1.0.0")\n'
              'bazel_dep(name = "package_metadata", version = "0.0.13")')
open(f"{pb}/MODULE.bazel", "w").write(m)
open(f"{pb}/REPO.bazel", "w").write('repo(default_package_metadata = ["//:license"])\n')
EOF
"${B[@]}" build //sbom:all --override_module=protobuf="$PB" \
  > "$R/build_sbom_protobuf_metadata.log" 2>&1
save_sboms sbom_protobuf_metadata
python3 "$TOOLS/sbom_components.py" "$R/sbom_protobuf_metadata" \
  "hypothetical: protobuf declares package_metadata" > "$R/sbom_components_protobuf_metadata.md"

# 6. Variant: prebuilt protoc off, using the metadata-enabled protobuf from
#    step 5 (the default SBOMs are empty, so comparing them shows nothing).
#    The toolchain is exec-config, so this should make no difference.
"${B[@]}" build //sbom:all --override_module=protobuf="$PB" \
  --@protobuf//bazel/flags:prefer_prebuilt_protoc=false \
  > "$R/build_sbom_prebuilt_false.log" 2>&1
save_sboms sbom_prebuilt_false
for f in "$R"/sbom_protobuf_metadata/*.json; do
  b="$(basename "$f")"
  if cmp -s <(sed 's/"created":"[^"]*"//' "$f") <(sed 's/"created":"[^"]*"//' "$R/sbom_prebuilt_false/$b"); then
    echo "$b: identical (ignoring timestamp)"
  else
    echo "$b: DIFFERS"
  fi
done > "$R/sbom_prebuilt_false_diff.txt"

# 7. Module graph (separate output base so it doesn't affect the fetch lists).
"${B_MOD[@]}" mod graph --include_builtin --output=json > "$R/mod_graph_builtin.json" 2>/dev/null
python3 "$TOOLS/module_list.py" "$R/mod_graph_builtin.json" > "$R/modules.txt"
diff <(grep -v '^#' ../01_minimal_proto_v37/results/modules.txt) <(grep -v '^#' "$R/modules.txt") \
  > "$R/modules_diff_vs_01.txt" || true
