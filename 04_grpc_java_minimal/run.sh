#!/bin/bash
# grpc-java 1.71.0 (with Bazel 9.3.0's patches) + protobuf 37.0-rc1.
# Does java_grpc_library force protobuf to be built from source?
cd "$(dirname "$0")"
source ../tools/common.sh
record_env

TARGETS=(greeter_proto greeter_java_proto greeter_java_grpc greeter_java_bin)

aquery() {
  # aquery <name> <target> [extra flags...]
  local name="$1" target="$2"
  shift 2
  "${B[@]}" aquery "deps(//proto:${target})" --output=jsonproto --include_artifacts=false "$@" \
    2>/dev/null | gzip > "$R/aquery_${name}.json.gz"
  python3 "$TOOLS/summarize_aquery.py" "$R/aquery_${name}.json.gz" "${name}" > "$R/aquery_${name}.md"
}

# 1. Action graph per target, with defaults.
for t in "${TARGETS[@]}"; do
  aquery "$t" "$t"
  fetched "fetched_after_${t}.txt"
done
sizes fetched_sizes_kib.txt

# 2. Same, with protobuf's bazel/private/native.bzl fixed (see 01 FINDINGS §1),
#    so that proto_library and java_proto_library really use the prebuilt
#    protoc. That isolates what java_grpc_library adds.
OUTPUT_BASE_DIR="$("${B[@]}" info output_base 2>/dev/null)"
PATCHED="${OUTPUT_BASE}-patched-protobuf"
rm -rf "$PATCHED"
cp -rL "${OUTPUT_BASE_DIR}/external/protobuf+" "$PATCHED"
sed -i 's|^native_proto_common = .*|native_proto_common = proto_common_do_not_use|' "$PATCHED/bazel/private/native.bzl"
grep -n '^native_proto_common' "$PATCHED/bazel/private/native.bzl" > "$R/patched_native_bzl.txt"
for t in "${TARGETS[@]}"; do
  aquery "${t}_patched_native_bzl" "$t" "--override_module=protobuf=${PATCHED}"
done

# 3. Which edges bring in protoc, libprotoc and the gRPC plugin.
{
  for to in @protobuf//:protoc @protobuf//:protoc_lib @grpc-java//compiler:grpc_java_plugin; do
    echo "### somepath(//proto:greeter_java_grpc, $to)"
    "${B[@]}" cquery "somepath(//proto:greeter_java_grpc, $to)" \
      --override_module=protobuf="${PATCHED}" 2>/dev/null
    echo
  done
  echo "### allpaths(//proto:greeter_java_grpc, @protobuf//:protoc) (patched native.bzl)"
  "${B[@]}" cquery "allpaths(//proto:greeter_java_grpc, @protobuf//:protoc)" \
    --override_module=protobuf="${PATCHED}" 2>/dev/null
  echo
  echo "### grpc C++ (@grpc) targets in deps(//proto:greeter_java_bin)"
  "${B[@]}" cquery 'filter("^@@?grpc\+//", deps(//proto:greeter_java_bin))' 2>/dev/null \
    || true
  echo "(end)"
} > "$R/attribution.txt"

# 3b. What gRPC codegen needs on its own: protoc (hard-coded in grpc-java's
#     java_rpc_toolchain) and the grpc_java_plugin cc_binary, which links
#     libprotoc. Both are analyzed in the target configuration here; the
#     counts match their exec-config copies.
for nl in protoc=@protobuf//:protoc grpc_java_plugin=@grpc-java//compiler:grpc_java_plugin; do
  n="${nl%%=*}" l="${nl#*=}"
  "${B[@]}" aquery "deps($l)" --output=jsonproto --include_artifacts=false \
    --override_module=protobuf="${PATCHED}" 2>/dev/null | gzip > "$R/aquery_only_${n}.json.gz"
  python3 "$TOOLS/summarize_aquery.py" "$R/aquery_only_${n}.json.gz" "deps($l)" > "$R/aquery_only_${n}.md"
done

# 4. Protobuf Java runtimes on the java_binary's classpath: protobuf's own
#    //java/core (built from source) vs a Maven protobuf-java jar.
{
  echo "### jars in the runfiles of //proto:greeter_java_bin (JDK jars omitted)"
  "${B[@]}" cquery //proto:greeter_java_bin --output=starlark \
    --starlark:expr='"\n".join([f.short_path for f in providers(target)["DefaultInfo"].default_runfiles.files.to_list() if f.short_path.endswith(".jar")])' \
    2>/dev/null | grep -v -e remotejdk -e local_jdk | sort
  echo
  echo "### Maven targets in deps(//proto:greeter_java_bin) matching 'protobuf'"
  "${B[@]}" cquery 'filter("maven.*protobuf", deps(//proto:greeter_java_bin))' 2>/dev/null || true
  echo "(end)"
} > "$R/java_runtimes.txt"

# 5. Module graph.
"${B_MOD[@]}" mod graph > "$R/mod_graph.txt" 2>/dev/null
"${B_MOD[@]}" mod graph --include_builtin --output=json > "$R/mod_graph_builtin.json" 2>/dev/null
python3 "$TOOLS/module_list.py" "$R/mod_graph_builtin.json" > "$R/modules.txt"
diff <(grep -v '^#' ../01_minimal_proto_v37/results/modules.txt) <(grep -v '^#' "$R/modules.txt") \
  > "$R/modules_diff_vs_01.txt" || true
for m in grpc-java protobuf grpc envoy_api googleapis rules_foreign_cc google_benchmark; do
  echo "### $m"
  "${B_MOD[@]}" mod explain --include_builtin "$m" 2>/dev/null || echo "($m is not in the module graph)"
done > "$R/mod_explain.txt"

# 6. Same project with the latest grpc-java (1.84.0, no patches needed) in a
#    temporary copy of the workspace.
WS184="${OUTPUT_BASE}-ws-grpc-java-1.84.0"
rm -rf "$WS184"; mkdir -p "$WS184"
cp -r .bazelversion .bazelrc BUILD.bazel proto "$WS184/"
cat > "$WS184/MODULE.bazel" <<'EOF'
module(name = "grpc_java_minimal_1_84")

bazel_dep(name = "protobuf", version = "37.0-rc1")
bazel_dep(name = "grpc-java", version = "1.84.0")
bazel_dep(name = "rules_java", version = "9.3.0")
EOF
B184=(bazel --nohome_rc --nosystem_rc "--output_base=${OUTPUT_BASE}-1.84.0" --max_idle_secs=600)
(
  cd "$WS184"
  for t in greeter_java_grpc greeter_java_bin; do
    for v in default patched_native_bzl; do
      extra=()
      [[ "$v" == patched_native_bzl ]] && extra=("--override_module=protobuf=${PATCHED}")
      "${B184[@]}" aquery "deps(//proto:$t)" --output=jsonproto --include_artifacts=false "${extra[@]}" \
        2>/dev/null | gzip > "$OLDPWD/$R/aquery_grpc_java_1.84.0_${t}_${v}.json.gz"
      python3 "$TOOLS/summarize_aquery.py" "$OLDPWD/$R/aquery_grpc_java_1.84.0_${t}_${v}.json.gz" \
        "grpc-java 1.84.0: ${t} (${v})" > "$OLDPWD/$R/aquery_grpc_java_1.84.0_${t}_${v}.md"
    done
  done
  "${B184[@]}" mod graph --include_builtin --output=json 2>/dev/null > "$OLDPWD/$R/mod_graph_grpc_java_1.84.0.json"
)
python3 "$TOOLS/module_list.py" "$R/mod_graph_grpc_java_1.84.0.json" > "$R/modules_grpc_java_1.84.0.txt"

# 7. What-ifs that split the from-source cost of java_grpc_library between
#    protoc and the gRPC plugin. Both use the patched native.bzl protobuf.
#    A: grpc-java takes protoc from the proto toolchain (prebuilt) instead of
#       its hard-coded @com_google_protobuf//:protoc.
#    B: A, plus the plugin is the prebuilt protoc-gen-grpc-java from Maven
#       Central instead of the //compiler:grpc_java_plugin cc_binary.
GA="${OUTPUT_BASE}-grpc-java-toolchain-protoc"
GB="${OUTPUT_BASE}-grpc-java-prebuilt-plugin"
rm -rf "$GA" "$GB"
cp -rL "${OUTPUT_BASE_DIR}/external/grpc-java+" "$GA"; chmod -R u+w "$GA"
python3 - "$GA/java_grpc_library.bzl" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
for old, new in [
    ('default = Label("@com_google_protobuf//:protoc"),', 'default = None,'),
    ('executable = toolchain.protoc[DefaultInfo].files_to_run,',
     'executable = ctx.toolchains["@com_google_protobuf//bazel/private:proto_toolchain_type"].proto.proto_compiler,'),
    ('toolchains = ["@bazel_tools//tools/jdk:toolchain_type"],',
     'toolchains = ["@bazel_tools//tools/jdk:toolchain_type", "@com_google_protobuf//bazel/private:proto_toolchain_type"],'),
]:
    assert old in s, old
    s = s.replace(old, new)
open(p, "w").write(s)
PY
cp -r "$GA" "$GB"
PLUGIN_URL=https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/1.71.0/protoc-gen-grpc-java-1.71.0-linux-x86_64.exe
curl -sSfL -o "$GB/compiler/protoc-gen-grpc-java.exe" "$PLUGIN_URL"
echo "965a390dc243619c4fc7d69047d6fd7193466d0f  $GB/compiler/protoc-gen-grpc-java.exe" | sha1sum -c --quiet
chmod +x "$GB/compiler/protoc-gen-grpc-java.exe"
# The plugin attr takes only executable rules, so wrap the file in one.
cat > "$GB/compiler/prebuilt.bzl" <<'BZL'
def _prebuilt_exe_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = out, target_file = ctx.file.src, is_executable = True)
    return [DefaultInfo(executable = out, files = depset([out]))]

prebuilt_exe = rule(
    implementation = _prebuilt_exe_impl,
    attrs = {"src": attr.label(allow_single_file = True)},
    executable = True,
)
BZL
sed -i 's|plugin = "//compiler:grpc_java_plugin",|plugin = "//compiler:prebuilt_grpc_java_plugin",|' "$GB/compiler/BUILD.bazel"
cat >> "$GB/compiler/BUILD.bazel" <<'BZL'

load(":prebuilt.bzl", "prebuilt_exe")

prebuilt_exe(
    name = "prebuilt_grpc_java_plugin",
    src = "protoc-gen-grpc-java.exe",
)
BZL
for t in greeter_java_grpc greeter_java_bin; do
  aquery "${t}_toolchain_protoc" "$t" "--override_module=protobuf=${PATCHED}" "--override_module=grpc-java=${GA}"
  aquery "${t}_prebuilt_plugin" "$t" "--override_module=protobuf=${PATCHED}" "--override_module=grpc-java=${GB}"
done
