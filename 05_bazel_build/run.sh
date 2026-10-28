#!/bin/bash
# Bazel 9.3.0's own build (run checkout.sh first). Analysis only: which
# protobuf pieces does //src:bazel_nojdk build from source, and why?
cd "$(dirname "$0")"
source ../tools/common.sh
R="$PWD/results"
cd bazel
record_env
git rev-parse HEAD >> "$R/env.txt"

TARGET=//src:bazel_nojdk
PREBUILT=--@com_google_protobuf//bazel/toolchains:prefer_prebuilt_protoc=true

aquery() {
  # aquery <name> [extra flags...]
  local name="$1"
  shift
  "${B[@]}" aquery "deps($TARGET)" --output=jsonproto --include_artifacts=false "$@" \
    2>/dev/null | gzip > "$R/aquery_${name}.json.gz"
  python3 "$TOOLS/summarize_aquery.py" "$R/aquery_${name}.json.gz" "${name}" > "$R/aquery_${name}.md"
}

# 1. Proto toolchain resolution, default and with prebuilt protoc.
for v in default prebuilt; do
  extra=()
  [[ "$v" == prebuilt ]] && extra=("$PREBUILT")
  "${B[@]}" cquery "$TARGET" --toolchain_resolution_debug=proto_toolchain_type "${extra[@]}" 2>&1 \
    | grep -e 'proto_toolchain_type' | sed 's/^INFO: //' | sort | uniq -c | sort -rn | head -40 \
    > "$R/toolchain_resolution_${v}.txt" || true
done

# 2. Action graph with Bazel's own settings (prefer_prebuilt_protoc is off by
#    default in protobuf 33.4 and Bazel's .bazelrc doesn't set it).
aquery bazel_nojdk
fetched fetched_after_aquery.txt
sizes fetched_sizes_kib.txt

# 3. Same with the prebuilt protoc.
aquery bazel_nojdk_prebuilt "$PREBUILT"

# 4. Attribution.
{
  for to in @com_google_protobuf//:protoc @com_google_protobuf//:protoc_lib \
      @grpc-java//compiler:grpc_java_plugin @com_google_protobuf//:protobuf \
      @com_google_protobuf//java/core:core; do
    echo "### somepath($TARGET, $to) ($PREBUILT)"
    "${B[@]}" cquery "somepath($TARGET, $to)" "$PREBUILT" 2>/dev/null || true
    echo
  done
  echo "### rdeps(deps($TARGET), @com_google_protobuf//:protobuf, 1): C++ that links the protobuf runtime"
  "${B[@]}" cquery "rdeps(deps($TARGET), @com_google_protobuf//:protobuf, 1)" "$PREBUILT" 2>/dev/null || true
  echo
  echo "### rdeps(deps($TARGET), @com_google_protobuf//java/core:core, 1)"
  "${B[@]}" cquery "rdeps(deps($TARGET), @com_google_protobuf//java/core:core, 1)" "$PREBUILT" 2>/dev/null || true
  echo
  echo "### cc_binary targets in deps($TARGET)"
  "${B[@]}" cquery "kind(cc_binary, deps($TARGET))" "$PREBUILT" 2>/dev/null || true
  echo
  echo "### grpc C++ (@com_github_grpc_grpc) targets in deps($TARGET)"
  "${B[@]}" cquery "filter('^@@?(com_github_grpc_grpc|grpc\+)//', deps($TARGET))" "$PREBUILT" 2>/dev/null || true
  echo
  echo "### Maven targets in deps($TARGET) matching 'protobuf'"
  "${B[@]}" cquery "filter('maven.*protobuf', deps($TARGET))" "$PREBUILT" 2>/dev/null || true
  echo "(end)"
} > "$R/attribution.txt"

# 5. What-ifs on top of the prebuilt protoc (see 04 FINDINGS §2): grpc-java's
#    java_grpc_library uses the toolchain's protoc, and then also the prebuilt
#    protoc-gen-grpc-java. The copies start from the already-patched
#    grpc-java Bazel fetched.
OUTPUT_BASE_DIR="$("${B[@]}" info output_base 2>/dev/null)"
GA="${OUTPUT_BASE}-grpc-java-toolchain-protoc"
GB="${OUTPUT_BASE}-grpc-java-prebuilt-plugin"
"$TOOLS/patch_grpc_java.sh" "${OUTPUT_BASE_DIR}/external/grpc-java+" "$GA" "$GB" \
  1.71.0 965a390dc243619c4fc7d69047d6fd7193466d0f
aquery bazel_nojdk_prebuilt_toolchain_protoc "$PREBUILT" "--override_module=grpc-java=${GA}"
aquery bazel_nojdk_prebuilt_plugin "$PREBUILT" "--override_module=grpc-java=${GB}"

# 5b. What still needs protobuf's C++ tools in the best case above.
{
  for to in @com_google_protobuf//src/google/protobuf/compiler/cpp:protoc-gen-cpp \
      @com_github_grpc_grpc//src/compiler:grpc_cpp_plugin_native \
      @com_google_protobuf//upb_generator/c:protoc-gen-upb_stage1 @com_google_protobuf//:protoc; do
    echo "### somepath($TARGET, $to) (prebuilt protoc + prebuilt grpc-java plugin)"
    "${B[@]}" cquery "somepath($TARGET, $to)" "$PREBUILT" "--override_module=grpc-java=${GB}" 2>/dev/null || true
    echo
  done
  echo "(end)"
} > "$R/attribution_prebuilt_plugin.txt"

# 6. Module graph.
"${B_MOD[@]}" mod graph > "$R/mod_graph.txt" 2>/dev/null
"${B_MOD[@]}" mod graph --include_builtin --output=json > "$R/mod_graph_builtin.json" 2>/dev/null
python3 "$TOOLS/module_list.py" "$R/mod_graph_builtin.json" > "$R/modules.txt"
for m in protobuf grpc grpc-java googleapis-grpc-java rules_kotlin rules_rust; do
  echo "### $m"
  "${B_MOD[@]}" mod explain --include_builtin "$m" 2>/dev/null || echo "($m is not in the module graph)"
done > "$R/mod_explain.txt"
