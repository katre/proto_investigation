# 03_minimal_proto_sbom: findings

This is the [01](../01_minimal_proto_v37/FINDINGS.md) project (protobuf **37.0-rc1**) plus SBOM generation from
[bazel-contrib/supply-chain](https://github.com/bazel-contrib/supply-chain).
supply-chain is pinned to `main` at [`df3e61f82ee285763f3ed5cbfc0fab1fedd976ec`](https://github.com/bazel-contrib/supply-chain/tree/df3e61f82ee285763f3ed5cbfc0fab1fedd976ec)
(2026-10-23) through `git_override` for `supply_chain_tools` (`tools/`),
`package_metadata` (`metadata/`) and `supply-chain-go` (`lib/supplychain-go/`).
[`sbom/BUILD.bazel`](sbom/BUILD.bazel) defines an `sbom` + `cyclonedx` + `spdx` triple for each of
the six `//proto` targets (`require_root_metadata = False`).

There is one change from 01: [`proto/BUILD.bazel`](proto/BUILD.bazel) sets
`default_visibility = ["//visibility:public"]` so `//sbom` can reference the
targets.

## 1. The SBOMs are empty

With protobuf 37.0-rc1 as published, **all 18 SBOM outputs contain no
components**. The graph has 0 nodes and 0 edges, and the CycloneDX `components`
and SPDX `packages` lists are both empty ([`results/sbom_components.md`](results/sbom_components.md)).
Running the `gather_metadata_info_and_write` aspect directly on each target
gives byte-identical graphs ([`results/aspect_vs_sbom.txt`](results/aspect_vs_sbom.txt)).

Why: the aspect only collects `PackageMetadataInfo`, `PackageAttributeInfo` and
`LicenseKindInfo` from `@package_metadata`. It finds them through a target's
`package_metadata` / `applicable_licenses` attribute. Here is how the modules
in these dependency graphs declare metadata:

| repo | declaration | provider | collected? |
|---|---|---|---|
| protobuf | `package(default_applicable_licenses = ["//:license"])` in about 110 packages, with `@rules_license` `license()` | `@rules_license` `LicenseInfo` | no |
| zlib | `default_applicable_licenses`, `@rules_license` `license()` | `LicenseInfo` | no |
| rules_java | same | `LicenseInfo` | no |
| abseil-cpp, rules_cc, bazel_tools | nothing | none | no |
| rules_jvm_external, toml.bzl, gazelle go_deps | `REPO.bazel` `default_package_metadata` | `PackageMetadataInfo` | yes, but none of their targets are in these graphs |

So for this project the SBOM doesn't just leave out the extra modules. It also
leaves out the protobuf runtime, abseil and zlib that a `cc_binary` actually
links. **Missing components are a bigger SBOM problem than extra ones.**

## 2. The extra modules can't appear, even with full metadata adoption

[`probe/traversal.bzl`](probe/traversal.bzl) is a copy of the aspect's traversal logic: the same
exec-config cutoff and the same `should_traverse` attribute filter. It records
every target it visits, whether or not that target has metadata. That gives the
largest SBOM possible if every module adopted `package_metadata`
([`results/traversal/`](results/traversal/), [`results/repo_comparison.md`](results/repo_comparison.md)):

| target | targets visited | repos visited |
|---|---|---|
| `greeting_proto` | 6 | main, protobuf |
| `greeting_py_proto` | 7 | main, protobuf |
| `greeting_java_proto` | 28 | main, protobuf, rules_java, bazel_tools |
| `greeting_java_bin` | 30 | main, protobuf, rules_java, bazel_tools |
| `greeting_cc_proto` | 174 | main, protobuf, abseil-cpp, zlib |
| `greeting_cc_bin` | 180 | main, protobuf, abseil-cpp, zlib, rules_cc, bazel_tools |

**rules_kotlin, rules_rust, rules_jvm_external, rules_go, rules_android,
rules_python, rules_pkg and rules_apple are never visited.** They are in the
module graph (35 modules, [`results/modules.txt`](results/modules.txt)), and most of them are even
fetched (see [§5](#5-cost-of-generating-the-sboms)), but none of their targets are in the target-config
dependency graph of any of these targets. The exec-config cutoff also drops
protoc, the protoc plugins, the JDKs, and the Python interpreter that
`java_proto_library` pulls in through `proguard_allowlister`.

What the cutoff leaves out, compared with `cquery deps(T)` in the target
configuration: `platforms`, `rules_license` (the license targets themselves),
`zlib` for the Java and Python targets, and
`protobuf++protoc+prebuilt_protoc.linux_x86_64`. None of these are shipped code.
`py_proto_library` doesn't visit the Python runtime (`rules_python`) because it
is reached only through a toolchain.

## 3. Hypothetical: protobuf adopts `package_metadata`

Step 5 of [`run.sh`](run.sh) patches a copy of protobuf to use the new metadata, then
reruns with `--override_module`. In `REPO.bazel` it adds
`default_package_metadata = ["//:license"]`. It also turns the root
`//:license` into a `package_metadata` target (purl
`pkg:bazel/protobuf@37.0-rc1`, `BSD-3-Clause`). Results are in
[`results/sbom_components_protobuf_metadata.md`](results/sbom_components_protobuf_metadata.md):

| target | graph nodes | components (CycloneDX and SPDX) |
|---|---|---|
| `greeting_proto` / `greeting_py_proto` | 5 | `protobuf@37.0-rc1` |
| `greeting_java_proto` / `greeting_java_bin` | 23 | `protobuf@37.0-rc1` |
| `greeting_cc_proto` / `greeting_cc_bin` | 40 | `protobuf@37.0-rc1` |

- The pipeline works: once a module declares metadata, it shows up.
- Still no rules_kotlin, rules_rust, etc.
- `greeting_proto` alone lists protobuf only because of `bazel/flags:*` build
  settings and `prebuilt:authenticity_validation`. That is a minor false
  positive: a bare `proto_library` ships no protobuf code.
- abseil and zlib would also need `package_metadata` to be listed for the C++
  targets.

## 4. Prebuilt protoc doesn't affect the SBOM

`--@protobuf//bazel/flags:prefer_prebuilt_protoc=false`, applied to the
metadata-enabled protobuf, gives output identical to [§3](#3-hypothetical-protobuf-adopts-package_metadata) apart from timestamps
([`results/sbom_prebuilt_false_diff.txt`](results/sbom_prebuilt_false_diff.txt)). This is expected: protoc is an
exec-config toolchain and the aspect never follows it.

## 5. Cost of generating the SBOMs

- **No protobuf code is compiled.** `bazel build //sbom:all` ran 53 spawns
  ([`results/executed_sbom_all.md`](results/executed_sbom_all.md)), all of them the Go SBOM tools and their
  deps (GoCompilePkg/GoLink for supply-chain-go, spdx/tools-golang,
  cyclonedx-go, ...), plus 6 `SbomClassify`. The aspect only needs analysis.
  `deps(//sbom:all)` contains 3262 potential actions
  ([`results/aquery_sbom_all.md`](results/aquery_sbom_all.md)), and none of them run.
- **Fetches: 116 repos, about 2.3 GiB** ([`results/fetched_after_sbom_build.txt`](results/fetched_after_sbom_build.txt),
  [`results/fetched_sizes_kib.txt`](results/fetched_sizes_kib.txt)), compared with 85 for [01](../01_minimal_proto_v37/FINDINGS.md#5-what-is-actually-fetched)'s `proto_library`.
  Like [01](../01_minimal_proto_v37/FINDINGS.md#5-what-is-actually-fetched), this includes rules_kotlin, rules_rust, rules_go, rules_android and
  rules_jvm_external, because their registered toolchains are loaded during
  toolchain resolution.
- **About 690 MiB of that is SBOM validators.** supply_chain_tools registers
  `toolchain()` targets inside the `cyclonedx_cli_*` repos (8 platforms,
  about 75–87 MiB each) and `spdx_tools_java` (60 MiB). `cyclonedx` and `spdx`
  declare the validator toolchain types as mandatory. Validation is off by
  default (`//sbom:strict_validations`), but resolving the toolchains still
  fetches all nine repos. This is the same pattern that makes protobuf's
  module deps expensive: `toolchain()` declared in the repo holding the heavy
  payload.

## 6. Module graph

There are 35 modules, compared with 33 in [01](../01_minimal_proto_v37/FINDINGS.md#4-module-graph) ([`results/modules_diff_vs_01.txt`](results/modules_diff_vs_01.txt)).
The new ones are `supply_chain_tools` and `supply-chain-go`. supply-chain's
`main` also bumps `bazel_features` 1.43.0 → 1.46.0, `rules_go` 0.59.0 → 0.60.0,
and `package_metadata` 0.0.7 → the overridden commit.
