# 01_minimal_proto_v37: findings

One `greeting.proto` (a single message, no imports) with protobuf **37.0-rc1**,
Bazel 9.3.0. The targets are `proto_library`, `cc_proto_library`,
`java_proto_library` and `py_proto_library`, plus trivial `cc_binary` and
`java_binary` consumers. The only extra `bazel_dep`s are `rules_cc` and
`rules_java`, at the versions protobuf already resolves to. Raw outputs are in
[`results/`](results/); the aquery summaries are [`results/aquery_*.md`](results/).

## 1. Prebuilt protoc is never used: protobuf 37.0-rc1 regression

**With protobuf 37.0-rc1 on Bazel 9.3.0, every protoc invocation needed to build
a `.proto` uses a protoc built from source.** That holds even though
`prefer_prebuilt_protoc` defaults to `true` and the prebuilt protoc repo is set up.

| target | actions | protoc used |
|---|---|---|
| `proto_library` | **1143** (1142 in exec config: protobuf, abseil, zlib) | `src/google/protobuf/compiler:protoc_minimal`, from source |
| `cc_proto_library` | 2882 | `protoc_minimal` + full `protoc` (`@protobuf//bazel/flags:proto_compiler` → `@bazel_tools//tools/proto:protoc`), both from source |
| `java_proto_library` | 2150 | same; only the internal `ProtoCompile` for the bundled WKTs uses the prebuilt binary |
| `py_proto_library` | 2260 | same |

Setting `--@protobuf//bazel/flags:prefer_prebuilt_protoc=false` changes nothing
([`aquery_greeting_proto_prebuilt_false.md`](results/aquery_greeting_proto_prebuilt_false.md), [`aquery_greeting_cc_proto_prebuilt_false.md`](results/aquery_greeting_cc_proto_prebuilt_false.md)).

**Root cause.** [`bazel/private/native.bzl`](https://github.com/protocolbuffers/protobuf/blob/v37.0-rc1/bazel/private/native.bzl) in 37.0-rc1 has:

```starlark
native_proto_common = getattr(native, "proto_common", None)
```

and [`bazel/private/toolchain_helpers.bzl`](https://github.com/protocolbuffers/protobuf/blob/v37.0-rc1/bazel/private/toolchain_helpers.bzl) uses it to decide whether proto
toolchain resolution is enabled:

```starlark
_incompatible_toolchain_resolution = getattr(native_proto_common, "INCOMPATIBLE_ENABLE_PROTO_TOOLCHAIN_RESOLUTION", False)
```

Bazel 9.3.0 has no `native.proto_common`. The object is the top-level
`proto_common_do_not_use`, and its `INCOMPATIBLE_ENABLE_PROTO_TOOLCHAIN_RESOLUTION`
is `True` (`--incompatible_enable_proto_toolchain_resolution` defaults to true,
see [`results/bazel_proto_flags.txt`](results/bazel_proto_flags.txt)). A probe `.bzl` in Bazel 9.3.0 printed:

```
hasattr(native, 'proto_common') = False
proto_common_do_not_use.INCOMPATIBLE_ENABLE_PROTO_TOOLCHAIN_RESOLUTION = True
```

So protobuf always takes the legacy (non-toolchain) path:

- `proto_library` gets the `_proto_compiler` attribute, which defaults to
  `//src/google/protobuf/compiler:protoc_minimal`.
- `proto_lang_toolchain` uses `--proto_compiler`, i.e. the source-built
  `@com_google_protobuf//:protoc`.

The prebuilt toolchains registered under `//bazel/private/oss/toolchains/prebuilt`
are never consulted. [`results/toolchain_resolution.txt`](results/toolchain_resolution.txt) shows no resolution of
`proto_toolchain_type` at all.

protobuf 33.4 and 36.2 had `native_proto_common = proto_common_do_not_use` and
are not affected (see [02](../02_minimal_proto_v33/FINDINGS.md)). The change came in protobuf commit
[`f1c23cb`](https://github.com/protocolbuffers/protobuf/commit/f1c23cb216347437d0a190a23b9ecf46873db367)
("Prepare Protobuf for a future version of Bazel which will lack the proto
fragment", 2026-08-25) and is still on `main`.

**Confirmation.** We re-ran with `--override_module=protobuf=<copy of
protobuf+ with native.bzl restored to proto_common_do_not_use>`
([`results/patched_native_bzl.txt`](results/patched_native_bzl.txt)):

| target | actions, 37.0-rc1 as released | actions, `native.bzl` fixed |
|---|---|---|
| `proto_library` | 1143 | **2** (prebuilt protoc) |
| `java_proto_library` | 2150 | **79** (prebuilt protoc; 2 `Javac` for the protobuf Java runtime) |
| `cc_proto_library` | 2882 | 1980 (see [§2](#2-c-still-builds-protobuf-from-source-even-with-the-fix)) |

## 2. C++ still builds protobuf from source, even with the fix

With `native.bzl` fixed, `cc_proto_library` uses the prebuilt `protoc` but still
has **1181 exec-config actions** (protobuf 430, abseil 713, zlib 35). The C++
`proto_lang_toolchain` (`@protobuf//:cc_toolchain`) sets

```starlark
plugin = "//src/google/protobuf/compiler/cpp:protoc-gen-cpp",
```

so every C++ generation runs
`prebuilt protoc --plugin=protoc-gen-cpp=bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/cpp/protoc-gen-cpp`,
and that plugin is compiled from source against libprotoc. The prebuilt protoc
from the same release already includes the C++ generator (`--cpp_out`). The
plugin probably exists to keep the C++ generator exactly in sync with the
source-built runtime (e.g. when protobuf is patched), but it means the prebuilt
protoc saves almost nothing for C++ users.

The **C++ runtime** (`@protobuf//src/google/protobuf` + abseil + zlib) accounts
for about 800 target-config actions in both cases. That cost is expected: there's
no prebuilt C++ runtime.

## 3. Java and Python runtimes

- **Java**: `@protobuf//java/core:core` and `:lite_runtime_only` are compiled from
  source (2 `Javac` + 2 `Turbine`), plus generation of the Java well-known types.
  That's cheap next to the C++ work.
- **Python**: `py_proto_library` only generates code. The Python runtime is
  source files, and the only compiled work is the protoc build from [§1](#1-prebuilt-protoc-is-never-used-protobuf-370-rc1-regression).

## 4. Module graph

`bazel mod graph --include_builtin` gives **33 modules** ([`results/modules.txt`](results/modules.txt));
the baseline ([00](../00_empty_baseline/FINDINGS.md#module-graph)) has 28. Diff: [`results/modules_diff_vs_baseline.txt`](results/modules_diff_vs_baseline.txt). Compared
with the baseline, protobuf 37.0-rc1:

- **adds** `rules_rust@0.69.0` (now a non-dev dep), `rules_go@0.59.0`,
  `gazelle@0.47.0`, `bazel_lib@3.1.0`, `toml.bzl`, `rules_robolectric`,
  `bazel_worker_api`/`bazel_worker_java`, `package_metadata`, and `abseil-py`
- **upgrades** `rules_kotlin` 1.9.6 → 2.3.20, `rules_jvm_external` 6.7 → 6.9,
  `rules_python` 1.7.0 → 2.3.0, `rules_android` 0.1.1 → 0.7.1, `rules_java` → 9.3.0

`rules_kotlin` comes directly from protobuf and through `rules_jvm_external`;
`rules_rust` comes directly from protobuf ([`results/mod_explain.txt`](results/mod_explain.txt)).

## 5. What is actually fetched

Analyzing **only the `proto_library`** (`bazel cquery //proto:greeting_proto` in a
fresh output base) fetches **85 repos** ([`results/fetched_after_proto_library_cquery.txt`](results/fetched_after_proto_library_cquery.txt)).
These include `rules_kotlin+` (55 MB), `rules_rust+` (35 MB) and its Rust
toolchains hub, `rules_go+` (14 MB) and the Go SDK hub, `rules_android+` (8 MB)
and the Android SDK repo, `bazel_lib+` and its toolchains, and
`protobuf+` (58 MB).

As in [00](../00_empty_baseline/FINDINGS.md#what-is-actually-fetched), this happens because computing the registered toolchains loads every
`register_toolchains()` target in the graph. With the `native.bzl` fix, where only `proto_toolchain_type` is resolved,
81 repos are still fetched, including all of the above. So this cost is
independent of the regression in [§1](#1-prebuilt-protoc-is-never-used-protobuf-370-rc1-regression).

`java_proto_library` additionally fetches ([`results/fetched_after_greeting_java_proto.txt`](results/fetched_after_greeting_java_proto.txt)):

- the prebuilt protoc (11 MB)
- `remotejdk25_linux` (406 MB) and `remotejdk11_linux` (324 MB)
- the Java tools (83 MB)
- `rules_jvm_external+` (9 MB)
- **a hermetic Python 3.11 interpreter (151 MB)**. This comes from the Java
  toolchain: `@rules_java//toolchains:toolchain_java11` →
  `@bazel_tools//tools/jdk:proguard_allowlister`, a `py_binary`. It is not caused
  by protobuf.

Total `external/` size after all targets: about 1.5 GB ([`results/fetched_sizes_kib.txt`](results/fetched_sizes_kib.txt)).
