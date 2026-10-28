# 02_minimal_proto_v33: findings

Same project as 01, but with protobuf **33.4**, the version `bazel_tools`
already depends on, so the module graph is identical to the 00 baseline
(`results/modules_diff_vs_baseline.txt` is empty). In 33.4,
`@protobuf//bazel/toolchains:prefer_prebuilt_protoc` defaults to **false**.

## 1. Prebuilt protoc works, but only when opted in

`bazel/private/native.bzl` in 33.4 is `native_proto_common = proto_common_do_not_use`
(`results/native_bzl.txt`), so proto toolchain resolution is enabled and the
01 regression doesn't apply.

| target | default (prebuilt off) | `--@protobuf//bazel/toolchains:prefer_prebuilt_protoc=true` |
|---|---|---|
| `proto_library` | **1939** actions: full `protoc` from source (protobuf 1179, abseil 720, zlib 35 in exec config) | **2** actions, prebuilt protoc |
| `cc_proto_library` | 2700 (`protoc` + `protoc_minimal` from source) | 1879: prebuilt protoc, but `protoc-gen-cpp` still built from source (1125 exec actions) |
| `java_proto_library` | 2014 | not measured separately |
| `py_proto_library` | 2124 | not measured separately |

Without the flag, a user of 33.4 (and so anyone relying only on Bazel 9.3.0's
built-in protobuf) builds protoc from source for every proto.

## 2. C++ plugin built from source, as in 01

With the prebuilt flag on, C++ generation runs the prebuilt `protoc` with
`--plugin=protoc-gen-cpp=…/src/google/protobuf/compiler/cpp/protoc-gen-cpp`, and
that plugin is compiled from source (1125 exec-config actions: protobuf 374,
abseil 713, zlib 35). This is the same behavior as 01 §2. The C++ runtime (about
750 target-config actions) is unavoidable.

## 3. Module graph and fetches

- `rules_kotlin@1.9.6` comes from protobuf (directly and through
  `rules_jvm_external`). `rules_rust` is **not** in the graph (dev-only in 33.4).
- Analyzing just `proto_library` fetches **71 repos**
  (`results/fetched_after_proto_library_cquery.txt`) versus 85 with 37.0-rc1.
  16 repos are fetched only with 37.0-rc1: `rules_rust+` and its toolchains,
  `rules_go+` and two Go SDK repos, `rules_android+` and the Android SDK repo,
  `bazel_lib+` and six toolchain repos, `toml.bzl+` and `proto_bazel_features`.
  2 are fetched only with 33.4: `rules_swift+` and its local config. Every new non-dev dependency that
  registers toolchains adds downloads for *every* protobuf user.
- `rules_kotlin+` (25 MB) and `protobuf+` (53 MB) are fetched in both versions.
- As in 01, `java_proto_library` adds the remote JDKs, Java tools,
  `rules_jvm_external+` and the hermetic Python interpreter used by the Java
  toolchain's `proguard_allowlister`.
