# 04_grpc_java_minimal: findings

The project is protobuf **37.0-rc1** plus **grpc-java 1.71.0**, the version
Bazel 9.3.0 uses, with the four patches Bazel 9.3.0 applies to it (copied into
[`third_party/`](third_party/)). Without the patches, 1.71.0 doesn't load on Bazel 9.
[`proto/BUILD.bazel`](proto/BUILD.bazel) has `greeter_proto` (one message pair and one `service`),
`greeter_java_proto`, `greeter_java_grpc` (`java_grpc_library`) and a
`greeter_java_bin` that uses them.

There are two deviations from the plan:

- **`google_benchmark` 1.9.4 is added as a direct dep.** grpc-java 1.71.0 brings
  in google_benchmark 1.8.5, which needs rules_foreign_cc 0.10.1, and that
  doesn't load on Bazel 9. Bazel's own module graph resolves google_benchmark to
  1.9.4 too.
- **No rules_jvm_external dep.** grpc-java brings it in.

## 1. Yes: java_grpc_library builds protobuf (and abseil) from source

Action counts from `aquery 'deps(T)'` ([`results/aquery_*.md`](results/)):

| target | defaults | patched native.bzl¹ |
|---|---|---|
| `greeter_proto` | 1143 | **2** |
| `greeter_java_proto` | 2145 | **74** |
| `greeter_java_grpc` | 2409 | **2406** |
| `greeter_java_bin` | 2430 | **2427** |

¹ As in [01](../01_minimal_proto_v37/FINDINGS.md#1-prebuilt-protoc-is-never-used-protobuf-370-rc1-regression), protobuf 37.0-rc1's [`bazel/private/native.bzl`](https://github.com/protocolbuffers/protobuf/blob/v37.0-rc1/bazel/private/native.bzl) never uses the
prebuilt protoc on Bazel 9 (see [`01_minimal_proto_v37/FINDINGS.md`](../01_minimal_proto_v37/FINDINGS.md#1-prebuilt-protoc-is-never-used-protobuf-370-rc1-regression)). The
"patched" column uses a copy of protobuf with that one line fixed.

Once protoc is really prebuilt, `proto_library` and `java_proto_library`
compile no C++ at all. Adding `java_grpc_library` brings the from-source build
right back: **2301 exec-config actions**, including 1174 CppCompile across
protobuf (660), abseil (480), zlib (30) and grpc-java (4). This covers
everything protoc needs.

grpc-java 1.84.0 (the latest, no patches needed; step 6) is the same: 2403 by
default and 2400 with the patched protobuf.

## 2. Why: two hard-coded from-source tools in java_rpc_toolchain

[`results/attribution.txt`](results/attribution.txt):

```
//proto:greeter_java_grpc
  -> @grpc-java//compiler:java_grpc_library_toolchain
       -> @protobuf//:protoc                    (exec, _protoc attr)
       -> @grpc-java//compiler:grpc_java_plugin (exec, plugin attr; cc_binary)
            -> @protobuf//:protoc_lib
```

- **protoc.** `java_rpc_toolchain` has
  `_protoc = attr.label(default = Label("@com_google_protobuf//:protoc"), cfg = "exec")`.
  It runs protoc from that attribute and never uses the proto toolchain, so
  `prefer_prebuilt_protoc` has no effect on it. Every other protoc invocation
  in the graph uses the prebuilt protoc. The single gRPC codegen `Action` uses
  `bazel-out/k8-opt-exec/bin/external/protobuf+/protoc`. This holds in both
  1.71.0 and 1.84.0.
- **The plugin.** `protoc-gen-grpc-java` is a `cc_binary` that links
  `@protobuf//:protoc_lib`. Building libprotoc also needs protobuf's bootstrap
  generators (`protoc_minimal`, `protoc-gen-upb*_stage0/1`). On its own,
  `deps(@protobuf//:protoc)` is 2800 actions and
  `deps(@grpc-java//compiler:grpc_java_plugin)` is 2925 ([`results/aquery_only_*.md`](results/)).
  Most of that is shared.

### What-ifs (step 7, patched copies of grpc-java)

The patched copies are made by [`tools/patch_grpc_java.sh`](../tools/patch_grpc_java.sh).

| variant | `greeter_java_grpc` | exec config | CppCompile |
|---|---|---|---|
| as published (patched native.bzl) | 2406 | 2301 | 1174 |
| A: protoc from the proto toolchain | 2365 | 2260 | 1164 |
| B: A + prebuilt `protoc-gen-grpc-java` from Maven Central | **170** | 65 | **0** |

- **A** (`_protoc` removed; the rule uses
  `ctx.toolchains["@com_google_protobuf//bazel/private:proto_toolchain_type"].proto.proto_compiler`)
  saves only 41 actions, because the plugin still needs libprotoc.
- **B** also replaces the plugin with the published
  `io.grpc:protoc-gen-grpc-java:1.71.0:linux-x86_64` executable. That
  removes all C++ compilation. **Both tools must be prebuilt.** Fixing only
  protoc doesn't help.

## 3. Java runtime: protobuf's own, built from source, and no Maven duplicate

The runtime jars of `greeter_java_bin` ([`results/java_runtimes.txt`](results/java_runtimes.txt)):

- protobuf: `protobuf+/java/core/libcore.jar` and `liblite_runtime_only.jar`.
  These are compiled from source (2 Javac + 2 Turbine actions, target config).
- **There is no Maven `protobuf-java` jar.** grpc-java's `maven.override` maps
  it to `@com_google_protobuf//:protobuf_java`.
- grpc-java's own `api`, `stub`, `protobuf` and `protobuf-lite` are also built
  from source (7 Javac).
- Maven jars: guava 33.2.1-android, proto-google-common-protos 2.29.0, jsr305,
  error_prone_annotations, failureaccess, j2objc-annotations, checker-qual,
  animal-sniffer-annotations.

The Java runtime build is cheap (tens of actions). The C++ tools in [§2](#2-why-two-hard-coded-from-source-tools-in-java_rpc_toolchain) are the
expensive part.

## 4. Module graph: grpc-java 1.71.0 brings in gRPC C++ and its world

grpc-java 1.71.0 gives **60 modules**, compared with 33 for [01](../01_minimal_proto_v37/FINDINGS.md#4-module-graph)
([`results/modules_diff_vs_01.txt`](results/modules_diff_vs_01.txt)). It adds grpc 1.69.0, envoy_api, xds,
googleapis, cel-spec, opencensus-*, opentelemetry-*, prometheus-cpp,
opentracing-cpp, boringssl, curl, c-ares, mbedtls, civetweb, libpfm,
google_benchmark, rapidjson, nlohmann_json, protoc-gen-validate, cython,
rules_apple, rules_swift and swift_argument_parser.

- `mod explain grpc` ([`results/mod_explain.txt`](results/mod_explain.txt)) shows grpc-java depends on
  grpc directly and through envoy_api, googleapis, opencensus-proto and xds.
- **No `@grpc` (C++) target is in any analyzed graph.** These modules are only
  resolved. The only extra fetches for `java_grpc_library` are
  `package_metadata` and 11 Maven repos (107 repos and about 1.2 GiB in total,
  [`results/fetched_*`](results/)).
- grpc-java **1.84.0** drops all of that: **38 modules**, only 5 more than [01](../01_minimal_proto_v37/FINDINGS.md#4-module-graph)
  (bazel_jar_jar, googleapis, googleapis-rules-registry, grpc-java,
  grpc-proto), plus a few version bumps.
