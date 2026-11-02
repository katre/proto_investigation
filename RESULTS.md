# Protobuf Rules Investigation: Results

These are the answers to the questions in [`investigation.md`](investigation.md). All runs use
Bazel 9.3.0 and are analysis only (`mod`/`query`/`cquery`/`aquery`). The one
exception is the SBOM targets in 03. Each case has a `run.sh` and a
`FINDINGS.md` with the details. The cases are:

- [`00_empty_baseline`](00_empty_baseline/FINDINGS.md)
- [`01_minimal_proto_v37`](01_minimal_proto_v37/FINDINGS.md) (protobuf 37.0-rc1)
- [`02_minimal_proto_v33`](02_minimal_proto_v33/FINDINGS.md) (protobuf 33.4)
- [`03_minimal_proto_sbom`](03_minimal_proto_sbom/FINDINGS.md)
- [`04_grpc_java_minimal`](04_grpc_java_minimal/FINDINGS.md)
- [`05_bazel_build`](05_bazel_build/FINDINGS.md)

## 1. Too many module dependencies

**Every Bazel 9.3.0 project already depends on protobuf, so it gets
`rules_kotlin` too.** `bazel_tools` ([`MODULE.tools`](https://github.com/bazelbuild/bazel/blob/9.3.0/src/MODULE.tools)) has `bazel_dep(protobuf, 33.4)`
to autoload the old native proto rules. With `--include_builtin`, an empty
project has 28 modules, including protobuf 33.4, rules_kotlin 1.9.6,
rules_jvm_external, rules_python, rules_java, rules_apple, rules_swift and
rules_android ([00](00_empty_baseline/FINDINGS.md#module-graph)).

- **The answer to "why do I depend on rules_kotlin?":** protobuf (both 33.4
  and 37.0-rc1) has a non-dev dep on it, and so does rules_jvm_external, which
  protobuf also depends on. The user doesn't have to use protobuf at all, since
  `bazel_tools` brings it in.
- **protobuf 37.0-rc1 makes it worse.** It goes to 33 modules ([01](01_minimal_proto_v37/FINDINGS.md#4-module-graph)). It adds
  `rules_rust` (now non-dev), `rules_go`, `gazelle`, `bazel_lib`, `toml.bzl`,
  `rules_robolectric`, `package_metadata` and `abseil-py`. It also upgrades
  rules_kotlin to 2.3.20, rules_python to 2.3.0 and rules_android to 0.7.1.
- **Modules aren't only resolved, they're downloaded.** Being in the graph
  doesn't by itself cause a fetch. But any toolchain resolution loads every
  `register_toolchains()` target in the graph, which means fetching every
  module that registers one, whatever toolchain type is being resolved.
  - For a single `cc_library` in an empty project, Bazel fetches 68 repos,
    including protobuf (53 MB) and rules_kotlin (25 MB) ([00](00_empty_baseline/FINDINGS.md#what-is-actually-fetched)).
  - For a `proto_library`, it fetches 71 repos with protobuf 33.4 ([02](02_minimal_proto_v33/FINDINGS.md#3-module-graph-and-fetches)) and
    85 with 37.0-rc1 ([01](01_minimal_proto_v37/FINDINGS.md#5-what-is-actually-fetched)). The extra 37.0-rc1 repos include rules_rust plus
    its toolchains, rules_go plus the Go SDK, rules_android plus the Android
    SDK repo, and bazel_lib toolchains.
- **grpc-java 1.71.0 (the version Bazel uses) adds 27 more modules** (60 in
  total). They include grpc C++, envoy_api, xds, opentelemetry, prometheus,
  boringssl and curl. None of their targets are analyzed for a Java-only user.
  grpc-java 1.84.0 has 38 modules ([04](04_grpc_java_minimal/FINDINGS.md#4-module-graph-grpc-java-1710-brings-in-grpc-c-and-its-world)).

### SBOMs ([03](03_minimal_proto_sbom/FINDINGS.md))

**The theory is wrong. The module-graph deps don't appear in supply-chain
SBOMs. The real problem is the reverse: the SBOMs are missing things.**

- The `gather_metadata_info` aspect follows the **target-config** dependency
  graph only. It doesn't follow exec-config deps or toolchains, and it
  ignores the module graph. A copy of its traversal rules never visits
  rules_kotlin, rules_rust, rules_jvm_external, rules_go, rules_android,
  rules_python, rules_pkg or rules_apple for any proto target. It also never
  visits protoc.
- With today's modules, **every SBOM is empty**. Even the cc_binary's SBOM
  doesn't list the protobuf runtime, abseil or zlib that it links. The aspect
  only collects `@package_metadata` providers, and protobuf, zlib and
  rules_java only declare `@rules_license` `license()` targets, which it
  ignores.
- When protobuf is patched to declare `package_metadata`, the SBOM shows
  exactly `protobuf@37.0-rc1` and nothing else. `prefer_prebuilt_protoc`
  doesn't change it.
- **Cost:** the SBOM tooling itself fetches about 690 MiB of validator
  toolchains (cyclonedx-cli for 8 platforms, plus spdx-tools) even with
  validation off. This is the same "toolchain declared in the payload repo"
  problem.

## 2. Too much time building protobuf

### Minimal project ([01](01_minimal_proto_v37/FINDINGS.md), [02](02_minimal_proto_v33/FINDINGS.md), [04](04_grpc_java_minimal/FINDINGS.md))

| | protobuf 33.4 (Bazel's built-in) | protobuf 37.0-rc1 |
|---|---|---|
| `prefer_prebuilt_protoc` default | **off** | on |
| `proto_library` actions, default | 1939 (protoc from source) | **1143** (protoc_minimal from source) |
| `proto_library` with prebuilt actually in effect | 2 | 2 (only with the native.bzl fix) |
| `java_proto_library`, prebuilt in effect | n/a | 74–79 |
| `cc_proto_library`, prebuilt in effect | 1879 (`protoc-gen-cpp` from source) | 1980 (same) |

Findings:

1. **protobuf 37.0-rc1 regression: the prebuilt protoc is never used on Bazel 9.**
   - [`bazel/private/native.bzl`](https://github.com/protocolbuffers/protobuf/blob/v37.0-rc1/bazel/private/native.bzl) reads `getattr(native, "proto_common", None)`.
     That is `None` on Bazel 9, so protobuf thinks proto toolchain resolution is
     off and uses the source-built `protoc_minimal`/`protoc`.
   - It came in with protobuf commit [`f1c23cb`](https://github.com/protocolbuffers/protobuf/commit/f1c23cb216347437d0a190a23b9ecf46873db367) and is still on `main`.
   - Restoring `native_proto_common = proto_common_do_not_use` fixes it:
     `proto_library` goes from 1143 actions to 2 ([01 §1](01_minimal_proto_v37/FINDINGS.md#1-prebuilt-protoc-is-never-used-protobuf-370-rc1-regression)).
2. **protobuf 33.4 needs an explicit opt-in.** Anyone relying on the protobuf
   built into Bazel 9.3.0 builds protoc from source unless they set
   `--@protobuf//bazel/toolchains:prefer_prebuilt_protoc=true` ([02 §1](02_minimal_proto_v33/FINDINGS.md#1-prebuilt-protoc-works-but-only-when-opted-in)).
3. **C++ always builds libprotoc.** The C++ `proto_lang_toolchain` runs the
   prebuilt protoc with `--plugin=protoc-gen-cpp`, and that plugin is a
   source-built `cc_binary` that links libprotoc: about 1100–1200 exec-config
   actions. The prebuilt protoc already contains the C++ generator ([01 §2](01_minimal_proto_v37/FINDINGS.md#2-c-still-builds-protobuf-from-source-even-with-the-fix), [02 §2](02_minimal_proto_v33/FINDINGS.md#2-c-plugin-built-from-source-as-in-01)).
4. **Runtimes (hypothesis 1).**
   - The C++ runtime (protobuf + abseil + zlib, about 750–800 actions) is
     always built from source because there is no prebuilt runtime.
   - The Java runtime (`java/core`) is also built from source, but it's
     cheap: 2 Javac + 2 Turbine actions.
   - The Python runtime is source files only.
5. **gRPC-Java (hypothesis 2): confirmed for a Java project ([04](04_grpc_java_minimal/FINDINGS.md)).** With the
   prebuilt protoc in effect, `java_proto_library` needs 74 actions. Adding one
   `java_grpc_library` brings it back up to **2406**, including 1174
   CppCompile actions. Both tools in grpc-java's `java_rpc_toolchain` are built
   from source:
   - `_protoc = Label("@com_google_protobuf//:protoc")` is hard-coded and
     ignores the proto toolchain.
   - `protoc-gen-grpc-java` is a `cc_binary` that links libprotoc.

   Making only protoc toolchain-aware saves 41 actions. Using the
   Maven-published prebuilt `protoc-gen-grpc-java` as well brings it down to
   **170 actions with no CppCompile**. grpc-java 1.84.0 behaves the same.

### Bazel's own build ([05](05_bazel_build/FINDINGS.md))

`//src:bazel_nojdk` has 9895 actions. With the defaults, every protoc is built
from source.

- **`prefer_prebuilt_protoc=true` works:** all 222 proto codegen actions switch
  to the prebuilt protoc. But it **removes zero actions.**
- **Fixing grpc-java** (toolchain protoc + prebuilt plugin) removes only 6.
  For Bazel, **gRPC-Java isn't the cause.** The cause is Bazel's C++ code:
  - `cc_proto_library` (process-wrapper's `execution_statistics`, the
    client's protos) needs the from-source `protoc-gen-cpp`.
  - The C++ client's `cc_grpc_library` for `command_server` runs gRPC C++'s
    `generate_cc`. That hard-codes `@com_google_protobuf//:protoc`, the same
    pattern as grpc-java, and needs the from-source `grpc_cpp_plugin`.

  Each of these needs libprotoc on its own, so the exec-config protobuf/abseil
  build (about 1220 CppCompile) stays.
- **The C++ gRPC client links grpc++ and the protobuf C++ runtime.** That
  adds about 1220 more target-config CppCompile actions (grpc, abseil,
  protobuf, c-ares, re2). There is no prebuilt alternative for these.
- **Bazel can't use the prebuilt protoc as things stand anyway.**
  [`third_party/protobuf.patch`](https://github.com/bazelbuild/bazel/blob/9.3.0/third_party/protobuf.patch) modifies protoc's Java generator
  (`compiler/java/full/message.cc`, the `transient memoizedIsInitialized`
  change). A prebuilt protoc would silently drop that change.

## Recommendations

| problem | fix | owner |
|---|---|---|
| 37.0-rc1 never uses the prebuilt protoc on Bazel 9 | fix [`native.bzl`](https://github.com/protocolbuffers/protobuf/blob/v37.0-rc1/bazel/private/native.bzl) (fall back to `proto_common_do_not_use`) before 37.0 final | protobuf |
| Bazel 9's built-in protobuf 33.4 defaults the prebuilt protoc off | bump `bazel_tools` to a protobuf whose prebuilt default works | Bazel |
| `cc_proto_library` always builds `protoc-gen-cpp` | use the prebuilt protoc's built-in `--cpp_out` when the prebuilt protoc is selected | protobuf |
| `java_grpc_library` / `cc_grpc_library` hard-code protoc and build their plugins from source | use the proto toolchain's protoc; offer prebuilt plugins (grpc-java already publishes them on Maven Central) | grpc-java, grpc |
| Every module that registers a toolchain is fetched by every user | keep language rules out of protobuf's non-dev deps, or register toolchains from small repos that don't hold the payload | protobuf, rules authors |
| SBOMs are empty / miss shipped code | adopt `package_metadata` (`REPO.bazel` `default_package_metadata`) in protobuf, abseil, zlib, etc. | module authors |
| Bazel's `message.cc` patch blocks the prebuilt protoc | get the change into a protobuf release | Bazel, protobuf |
