# 05_bazel_build: findings

This is Bazel's own build at tag 9.3.0 (`e89755b`), checked out by [`checkout.sh`](checkout.sh)
and built with Bazel 9.3.0. Its original [`.bazelversion`](https://github.com/bazelbuild/bazel/blob/9.3.0/.bazelversion) is 9.2.0
([`results/checkout.txt`](results/checkout.txt)). The target is `//src:bazel_nojdk`, analyzed only,
with Bazel's own [`.bazelrc`](https://github.com/bazelbuild/bazel/blob/9.3.0/.bazelrc).

Bazel's module setup ([`MODULE.bazel`](https://github.com/bazelbuild/bazel/blob/9.3.0/MODULE.bazel)):

- protobuf **33.4**, `repo_name = "com_google_protobuf"`, with `single_version_override`
  and [`third_party/protobuf.patch`](https://github.com/bazelbuild/bazel/blob/9.3.0/third_party/protobuf.patch).
- grpc-java **1.71.0**, with four patches.
- grpc **1.76.0.bcr.1** (`com_github_grpc_grpc`).
- googleapis-grpc-java 1.0.0.

The module graph has **71 modules** ([`results/modules.txt`](results/modules.txt)). `rules_kotlin`
1.9.6 comes through protobuf and rules_jvm_external. `rules_rust` is not in the
graph. Analysis fetches 187 repos, about 1.1 GiB ([`results/fetched_*`](results/)).

## 1. Bazel builds protoc from source, and the prebuilt flag barely matters

| variant | actions | exec config | exec CppCompile |
|---|---|---|---|
| defaults (`prefer_prebuilt_protoc` is off in 33.4 and not set by Bazel) | 9895 | 3141 | 1311 |
| `--@com_google_protobuf//bazel/toolchains:prefer_prebuilt_protoc=true` | **9895** | 3141 | 1311 |
| + grpc-java takes protoc from the toolchain ([04 what-if A](../04_grpc_java_minimal/FINDINGS.md#what-ifs-step-7-patched-copies-of-grpc-java)) | 9895 | 3141 | 1311 |
| + prebuilt `protoc-gen-grpc-java` ([04 what-if B](../04_grpc_java_minimal/FINDINGS.md#what-ifs-step-7-patched-copies-of-grpc-java)) | **9889** | 3135 | 1307 |

([`results/aquery_bazel_nojdk*.md`](results/))

**With the defaults, every protoc invocation uses a protoc built from source**
(222 `GenProto`/`GenProtoDescriptorSet`/`ProtoCompile`, plus 7 gRPC
codegen `Action`s). 23 of the `GenProto`s use `protoc_minimal`.

**With the prebuilt flag**, toolchain resolution picks
`prebuilt_protoc.linux_x86_64` ([`results/toolchain_resolution_*.txt`](results/)) and all
222 `proto_library`/`*_proto_library` invocations switch to the prebuilt
binary. But not one action is removed, because other consumers still need the
from-source protoc and libprotoc. The exec-config protobuf C++ build is the
same in all four rows: protobuf 660 CppCompile, abseil 511, zlib 30, grpc 18.

Even the best case (row 4: everything grpc-java needs is prebuilt) saves only
6 actions. Unlike the [04 minimal project](../04_grpc_java_minimal/FINDINGS.md#1-yes-java_grpc_library-builds-protobuf-and-abseil-from-source), **Bazel's from-source protobuf is not
caused by gRPC-Java**. It is caused by the C++ side of Bazel.

## 2. What still needs protobuf's C++ tools (best case)

[`results/attribution_prebuilt_plugin.txt`](results/attribution_prebuilt_plugin.txt) (somepath with the prebuilt protoc and
the prebuilt grpc-java plugin):

| tool built from source | needed by | why |
|---|---|---|
| `protoc-gen-cpp` (links libprotoc) | `//src/main/tools:process-wrapper` → `execution_statistics_cc_proto` | protobuf's C++ `proto_lang_toolchain` always runs this plugin, even with a prebuilt protoc (same as [01 §2](../01_minimal_proto_v37/FINDINGS.md#2-c-still-builds-protobuf-from-source-even-with-the-fix) and [02 §2](../02_minimal_proto_v33/FINDINGS.md#2-c-plugin-built-from-source-as-in-01)). The `cc_proto_library`s are `command_server`, `execution_statistics`, `failure_details`, plus the C++ well-known types. |
| `protoc` | `//src/main/cpp:client` → `command_server_cc_grpc` | gRPC C++'s `generate_cc` hard-codes `_protoc = Label("@com_google_protobuf//:protoc")`, the same pattern as grpc-java. |
| `grpc_cpp_plugin_native` (links libprotoc) | same `cc_grpc_library` | gRPC C++ codegen plugin |
| upb bootstrap generators (`protoc-gen-upb*_stage0/1`, `protoc-gen-upbdefs`, `protoc_minimal`) | libprotoc itself: `protoc_lib` → `compiler/rust` → `upb/reflection` | building any libprotoc consumer brings these in |

So there are three independent reasons for building libprotoc. Fixing just one
of them (grpc-java's) changes nothing.

1. **`cc_proto_library`'s plugin.** This is protobuf's own design, not gRPC.
2. **gRPC C++'s hard-coded protoc.**
3. **gRPC C++'s `grpc_cpp_plugin`.**

The client is the only part of Bazel that uses gRPC C++: it talks to the server
over gRPC.

## 3. Runtimes built from source (target configuration)

- **C++.** The Bazel client links `grpc++_unsecure` → `@com_google_protobuf//:protobuf`
  ([`results/attribution.txt`](results/attribution.txt)). That accounts for target-config CppCompile:
  grpc 518, abseil 432, protobuf 148, c-ares 91, re2 22, plus xds,
  googleapis and protoc-gen-validate. There is no prebuilt C++ runtime, so this
  is expected given Bazel's design (a C++ gRPC client).
- **Java.** `@com_google_protobuf//java/core:core` is compiled from source
  (3 Javac/Turbine in the target config, 2 in exec for annotation processors).
  That's cheap. There is no Maven `protobuf-java` jar in the graph. The only
  Maven matches are `io_grpc_grpc_protobuf` and `io_grpc_grpc_protobuf_lite`.
  grpc-java's own Java libraries are built from source (13 Javac).

## 4. Bazel's protobuf patch blocks the prebuilt protoc anyway

[`third_party/protobuf.patch`](https://github.com/bazelbuild/bazel/blob/9.3.0/third_party/protobuf.patch) changes three things:

- `java/core/BUILD.bazel` (exposes `lite_runtime_only`)
- `upb/BUILD` (partial revert for grpc)
- **`src/google/protobuf/compiler/java/full/message.cc`**, which emits
  `private transient byte memoizedIsInitialized` for messages with no required
  fields, to save memory in Bazel.

The last one changes **protoc's Java generator**. A prebuilt protoc doesn't have
it, so turning on `prefer_prebuilt_protoc` would silently change the Java code
generated for all of Bazel's protos. Bazel can't use the prebuilt protoc until
that change is in a protobuf release, which is presumably why the flag isn't
set. Since [§1](#1-bazel-builds-protoc-from-source-and-the-prebuilt-flag-barely-matters) shows the flag saves nothing today, this costs nothing at the
moment.

## Summary

| source of protobuf-from-source work in Bazel | can a prebuilt binary help? |
|---|---|
| protoc for `proto_library` / Java / C++ codegen | yes (the flag works), but blocked by the `message.cc` patch, and [§2](#2-what-still-needs-protobufs-c-tools-best-case) still needs libprotoc |
| `protoc-gen-cpp` for `cc_proto_library` | no: protobuf's C++ toolchain always builds the plugin from source |
| gRPC C++ `cc_grpc_library` (hard-coded protoc + `grpc_cpp_plugin`) | no: not toolchain-aware |
| grpc-java `java_grpc_library` (hard-coded protoc + `protoc-gen-grpc-java`) | no: not toolchain-aware, and removing it alone saves nothing in Bazel |
| C++ runtime (protobuf + grpc++ + abseil) for the client | no prebuilt runtime exists |
| Java runtime (`java/core`) | cheap |
