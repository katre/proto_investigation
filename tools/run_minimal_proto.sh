#!/bin/bash
# Shared methodology for 01_minimal_proto_v37 and 02_minimal_proto_v33.
# Must be run from the test case directory.
#
# Usage: run_minimal_proto.sh <prebuilt flag label> <non-default flag value>
#   e.g. run_minimal_proto.sh @protobuf//bazel/flags:prefer_prebuilt_protoc false
FLIP_FLAG="$1"
FLIP_VALUE="$2"
source "$(dirname "$0")/common.sh"
record_env

TARGETS=(greeting_proto greeting_cc_proto greeting_java_proto greeting_py_proto greeting_cc_bin greeting_java_bin)

aquery() {
  # aquery <name> <target> [extra flags...]
  local name="$1" target="$2"
  shift 2
  "${B[@]}" aquery "deps(//proto:${target})" --output=jsonproto --include_artifacts=false "$@" \
    2>/dev/null | gzip > "$R/aquery_${name}.json.gz"
  python3 "$TOOLS/summarize_aquery.py" "$R/aquery_${name}.json.gz" "${name}" > "$R/aquery_${name}.md"
}

# 1. Proto-related Bazel flags and their defaults.
"${B[@]}" help build 2>/dev/null | grep -i -A1 'proto' > "$R/bazel_proto_flags.txt" || true

# 2. Toolchain resolution for proto_library (fresh output base, before anything else).
"${B[@]}" cquery //proto:greeting_proto --toolchain_resolution_debug=proto_toolchain_type \
  > "$R/toolchain_resolution.txt" 2>&1 || true
fetched fetched_after_proto_library_cquery.txt

# 3. Action graph per target, with defaults. Record what each target adds to external/.
for t in "${TARGETS[@]}"; do
  aquery "$t" "$t"
  fetched "fetched_after_${t}.txt"
done
sizes fetched_sizes_kib.txt

# 4. Same, with the prebuilt-protoc flag flipped.
for t in greeting_proto greeting_cc_proto; do
  aquery "${t}_prebuilt_${FLIP_VALUE}" "$t" "--${FLIP_FLAG}=${FLIP_VALUE}"
done

# 5. Confirmation: protobuf with bazel/private/native.bzl reading
#    proto_common_do_not_use (as protobuf <= 36.x did) instead of
#    native.proto_common. Uses a patched copy of the fetched protobuf repo.
OUTPUT_BASE_DIR="$("${B[@]}" info output_base 2>/dev/null)"
PATCHED="${OUTPUT_BASE}-patched-protobuf"
rm -rf "$PATCHED"
cp -rL "${OUTPUT_BASE_DIR}/external/protobuf+" "$PATCHED"
sed -i 's|^native_proto_common = .*|native_proto_common = proto_common_do_not_use|' "$PATCHED/bazel/private/native.bzl"
grep -n '^native_proto_common' "$PATCHED/bazel/private/native.bzl" > "$R/patched_native_bzl.txt"
for t in greeting_proto greeting_cc_proto greeting_java_proto; do
  aquery "${t}_patched_native_bzl" "$t" "--override_module=protobuf=${PATCHED}"
done

# 6. Module graph (separate output base, see common.sh).
"${B_MOD[@]}" mod graph > "$R/mod_graph.txt" 2>/dev/null
"${B_MOD[@]}" mod graph --include_builtin --output=json > "$R/mod_graph_builtin.json" 2>/dev/null
python3 "$TOOLS/module_list.py" "$R/mod_graph_builtin.json" > "$R/modules.txt"
diff <(grep -v '^#' ../00_empty_baseline/results/modules.txt) <(grep -v '^#' "$R/modules.txt") \
  > "$R/modules_diff_vs_baseline.txt" || true
for m in rules_kotlin rules_rust rules_jvm_external rules_python rules_pkg rules_apple jsoncpp re2; do
  echo "### $m"
  "${B_MOD[@]}" mod explain --include_builtin "$m" 2>/dev/null || echo "($m is not in the module graph)"
done > "$R/mod_explain.txt"
"${B_MOD[@]}" mod graph --extension_info=usages --include_builtin > "$R/mod_graph_extensions.txt" 2>/dev/null || true
