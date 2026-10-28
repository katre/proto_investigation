#!/bin/bash
# Makes two what-if copies of a fetched grpc-java repo, for use with
# --override_module=grpc-java=<dir>:
#   <toolchain_protoc_dir>: java_grpc_library takes protoc from the proto
#     toolchain instead of its hard-coded @com_google_protobuf//:protoc.
#   <prebuilt_plugin_dir>: the same, plus the gRPC plugin is the prebuilt
#     protoc-gen-grpc-java from Maven Central instead of the cc_binary.
#
# Usage: patch_grpc_java.sh <grpc-java repo> <toolchain_protoc_dir> <prebuilt_plugin_dir> <version> <sha1>
set -euo pipefail
SRC="$1" GA="$2" GB="$3" VERSION="$4" SHA1="$5"
rm -rf "$GA" "$GB"
cp -rL "$SRC" "$GA"; chmod -R u+w "$GA"
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
curl -sSfL -o "$GB/compiler/protoc-gen-grpc-java.exe" \
  "https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/${VERSION}/protoc-gen-grpc-java-${VERSION}-linux-x86_64.exe"
echo "${SHA1}  $GB/compiler/protoc-gen-grpc-java.exe" | sha1sum -c --quiet
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
grep -q 'plugin = "//compiler:grpc_java_plugin",' "$GB/compiler/BUILD.bazel"
sed -i 's|plugin = "//compiler:grpc_java_plugin",|plugin = "//compiler:prebuilt_grpc_java_plugin",|' "$GB/compiler/BUILD.bazel"
cat >> "$GB/compiler/BUILD.bazel" <<'BZL'

load(":prebuilt.bzl", "prebuilt_exe")

prebuilt_exe(
    name = "prebuilt_grpc_java_plugin",
    src = "protoc-gen-grpc-java.exe",
)
BZL
