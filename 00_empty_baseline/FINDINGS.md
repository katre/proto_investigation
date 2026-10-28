# 00_empty_baseline: findings

A project with an empty `module()` and a single `filegroup`, using Bazel 9.3.0
(see `results/env.txt`).

## Module graph

- `bazel mod graph` only shows `<root>`, because builtin modules are hidden by default.
- `bazel mod graph --include_builtin` shows **27 modules besides `bazel_tools`**
  (`results/modules.txt`), all coming from Bazel's own `MODULE.tools`:

  ```
  abseil-cpp@20250814.1 apple_support@2.5.2 bazel_features@1.42.1 bazel_skylib@1.8.2
  buildozer@8.5.1 googletest@1.17.0 jsoncpp@1.9.6 nlohmann_json@3.6.1 platforms@1.0.0
  protobuf@33.4 pybind11_bazel@2.12.0 re2@2024-07-02.bcr.1 rules_android@0.1.1
  rules_apple@4.1.0 rules_cc@0.2.17 rules_java@9.1.0 rules_jvm_external@6.7
  rules_kotlin@1.9.6 rules_license@1.0.0 rules_pkg@1.0.1 rules_proto@7.1.0
  rules_python@1.7.0 rules_shell@0.6.1 rules_swift@3.1.2 stardoc@0.7.2
  swift_argument_parser@1.3.1.2 zlib@1.3.1.bcr.5
  ```

- **`rules_kotlin` is in every Bazel 9.3.0 project's module graph**, even with no
  protobuf usage. It comes from `bazel_tools`, which depends on protobuf 33.4 (to
  autoload the removed native proto rules); `rules_jvm_external` also requires it
  (`results/mod_explain.txt`):

  ```
  <root> (empty_baseline@_)
  └───bazel_tools@_
      └───protobuf@33.4
          ├───rules_jvm_external@6.7
          │   └───rules_kotlin@1.9.6
          └───rules_kotlin@1.9.6
  ```

- `rules_jvm_external` also comes only from protobuf (and from `stardoc`, which
  `rules_python` brings in as a non-dev dep); `rules_python` and `rules_java` come
  from `bazel_tools` directly as well as through protobuf.
- `rules_rust` is **not** in the graph (it's a dev-only dependency in protobuf 33.4).

## What is actually fetched

- `bazel query //...` and `bazel build --nobuild //...` in a fresh output base
  fetch only `platforms` (and `bazel_tools`/`_main`, which are local)
  (`results/fetched_after_analysis.txt`). A module being in the graph does
  **not** mean its archive gets downloaded during a normal build.
- **Running `bazel mod graph` / `mod explain` does fetch 22 module and extension
  repos**, including `protobuf+`, `rules_kotlin+`, `rules_jvm_external+`,
  `rules_swift+`, `rules_apple+` and `googletest+`
  (`results/fetched_by_mod_commands.txt`). The `mod` commands appear to evaluate
  module extensions (e.g. `bazel_features++version_extension+*` and
  `rules_python++python+pythons_hub` were created), which requires fetching the
  modules that define them. Users who run `bazel mod` to debug their graph will
  see these downloads and may reasonably assume their build needs them.

## Methodology notes

- `bazel clean --expunge` hangs in this environment (the old server becomes a
  zombie process that is never reaped), so every run uses a fresh
  `--output_base` instead (`tools/common.sh`). `bazel mod` commands run in a
  second output base so they don't affect the "fetched" lists.
- `--nohome_rc --nosystem_rc` is used so only the case's `.bazelrc` applies.
