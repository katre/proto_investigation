# Protobuf Rules Investigation: Test Plan

## Context

`investigation.md` lists two community complaints about the protobuf Bazel rules:

1. **Too many module dependencies.** Users ask why `rules_kotlin`, `rules_rust`, etc. show up. A related theory is that these deps also leak into SBOMs made by `bazel-contrib/supply-chain`.
2. **Too much time building protobuf.** This continues even with Bazel 9's prebuilt protoc support, and Bazel's own build is one example. Suspected causes: (a) a protobuf runtime is built from source, (b) the gRPC/gRPC-Java dependency forces parts of protobuf to be built from source.

This plan sets up isolated test cases (one subdirectory each) that answer those questions using **Bazel 9.3.0** and only `bazel mod` / `query` / `cquery` / `aquery`. The one exception is the SBOM case, which builds only the SBOM targets: the metadata aspect plus the small Go SBOM tool, never protobuf itself.

### Facts found while planning (to be confirmed by the tests)

- **Bazel 9.3.0's `MODULE.tools` (the `bazel_tools` module) has `bazel_dep(protobuf, 33.4)`**, along with rules_java 9.1.0, rules_python 1.7.0, rules_cc, etc. That means *every* Bazel 9.3.0 project has protobuf in its module graph, even if it uses no protos.
- protobuf **33.4** has non-dev deps on `rules_kotlin` 1.9.6, `rules_jvm_external`, `rules_java`, `rules_python`, `rules_pkg`, `rules_apple`, `jsoncpp`, `re2`, … (`rules_rust` is dev-only there).
- protobuf **37.0-rc1** makes `rules_rust` 0.69.0 a **non-dev** dep, keeps rules_kotlin 2.3.20, rules_jvm_external, rules_python, etc., and runs a non-dev `crate` extension and `maven` extension.
- **Prebuilt protoc default:** in 33.4, `@protobuf//bazel/toolchains:prefer_prebuilt_protoc` defaults to **False**. In 37.0-rc1 the flag is `@protobuf//bazel/flags:prefer_prebuilt_protoc` and defaults to **True**.
- **Bazel 9.3.0's own build** pins protobuf 33.4 via `single_version_override` with `third_party/protobuf.patch`. That patch changes `src/google/protobuf/compiler/java/full/message.cc`, which is protoc's Java generator, so a prebuilt protoc can't contain it. Bazel's `.bazelrc` never sets `prefer_prebuilt_protoc`. Bazel also depends on `grpc-java` 1.71.0 (patched), `grpc` 1.76.0, `googleapis-grpc-java`, and `googleapis-java`.
- **supply-chain SBOMs are target-graph based, not module-graph based.** The `gather_metadata_info` aspect uses `attr_aspects = ["*"]` and skips exec-configuration targets (`_is_exec_config` in `tools/gather_metadata/core.bzl`). Only modules whose targets are in the *target-config* dependency graph *and* that provide `package_metadata` should appear. The BCR has only `supply_chain_tools` 0.0.1, which is old, so we pin a recent `main` commit via `git_override`.

## Repository layout

```
.gitignore                       # bazel-*, */results/aquery_*.json.gz, 05_bazel_build/bazel/
PLAN.md
RESULTS.md                       # written at the end: answers to investigation.md
tools/
  summarize_aquery.py            # aquery jsonproto -> table of (repo, mnemonic, count) + flagged lists
  module_list.py                 # `bazel mod graph --output=json` -> sorted unique module@version list
  sbom_components.py             # cyclonedx/spdx json -> component list, mapped to module names
  fetched_repos.sh               # lists $(bazel info output_base)/external/* (repos actually fetched)
00_empty_baseline/
01_minimal_proto_v37/
02_minimal_proto_v33/
03_minimal_proto_sbom/
04_grpc_java_minimal/
05_bazel_build/
```

Every test-case directory contains:
- `.bazelversion`: `9.3.0`
- `MODULE.bazel`, `BUILD.bazel` / sources, and a committed `MODULE.bazel.lock` (for reproducibility)
- `.bazelrc`: `common --lockfile_mode=update` plus nothing else unless stated, so we measure the defaults
- `run.sh`: runs every command in the methodology below and writes raw output to `results/`
- `FINDINGS.md`: what was observed, with the important numbers and excerpts

Large raw outputs (aquery jsonproto) are stored gzipped and gitignored. Text outputs and summaries are committed.

### Shared tools (`tools/`), Python 3 stdlib only

- `summarize_aquery.py <aquery.jsonproto>`:
  - Groups actions by owning repo (canonical repo name taken from the action's target label, e.g. `@@protobuf+//...`) and mnemonic.
  - Separately lists: `CppCompile`/`CppLink*` actions in `protobuf+`, `abseil-cpp+`, `grpc+`, `grpc-java+`, `upb`; `Javac`/`Turbine` actions for protobuf Java targets; and the executable path of every `GenProto*` action, which shows whether protoc is prebuilt (`external/protobuf++protoc+prebuilt_protoc.*`) or built from source (`bazel-out/*-exec/bin/external/protobuf+/protoc`).
  - Emits a markdown table so `FINDINGS.md` can include it directly.
- `module_list.py`: flattens the mod-graph JSON into unique `name@version` entries and counts them, with and without dev deps / builtin modules.
- `sbom_components.py`: pulls component name/version/purl out of CycloneDX and SPDX output and matches each one to a module from `module_list.py`.

### General procedure for each case

1. `bazel clean --expunge` (a shared repository cache is fine) so `external/` reflects only that case.
2. Run the `bazel mod` commands first, then record `fetched_repos.sh` output. Repeat after query/aquery to separate "in the module graph" from "actually downloaded".
3. All analysis runs on the host platform (linux x86_64). Record `bazel version` and `uname -m` in `results/env.txt`.

---

## 00_empty_baseline: what Bazel 9.3.0 adds on its own

**Contents:** `MODULE.bazel` with only `module(name = "empty_baseline")`. `BUILD.bazel` with one `filegroup` over a text file. No protobuf usage.

**What is tested:** the module dependencies every Bazel 9.3.0 user gets before using protobuf. Hypothesis: protobuf 33.4 and therefore `rules_kotlin` 1.9.6 are already in the graph through `bazel_tools`.

**Methodology:**
1. `bazel mod graph` and `bazel mod graph --include_builtin`, saved as text and `--output=json`. Run `module_list.py` on each.
2. `bazel mod explain rules_kotlin rules_jvm_external rules_python rules_java rules_rust protobuf --include_builtin` to show the paths (expected: `bazel_tools → protobuf@33.4 → rules_kotlin`).
3. `bazel query //...`, then `fetched_repos.sh` to check whether any of these repos are actually *fetched* when nothing uses them.

**Output:** the baseline module count and list that later cases are compared against.

---

## 01_minimal_proto_v37 and 02_minimal_proto_v33: one proto file

The two directories are identical except for the protobuf version: `37.0-rc1` (prebuilt default on) versus `33.4` (same as `bazel_tools`, prebuilt default off).

**Contents:**
- `MODULE.bazel`: `bazel_dep(name = "protobuf", version = "37.0-rc1" | "33.4")`. Only the extra deps the language rules need to load are added: `rules_cc`, `rules_java`, `rules_python`, at the versions protobuf already requires so we don't change resolution.
- `proto/greeting.proto`: one message, no imports. Keeping it free of well-known types keeps it minimal.
- `proto/BUILD.bazel`, using the `@protobuf//bazel:*.bzl` loads:
  - `proto_library(name = "greeting_proto")`
  - `cc_proto_library(name = "greeting_cc_proto")`
  - `java_proto_library(name = "greeting_java_proto")`
  - `py_proto_library(name = "greeting_py_proto")`
  - `cc_binary(name = "greeting_cc_bin")` and `java_binary(name = "greeting_java_bin")`, trivial consumers that link the runtime, matching what a user actually ships.

**What is tested:**
- How many modules one protobuf dependency adds on top of the 00 baseline, and why language-specific ones like `rules_kotlin` and `rules_rust` are there.
- Which modules are actually fetched for each language target, as opposed to only resolved.
- For each language target: whether protoc is prebuilt or compiled from source, and which protobuf runtime pieces are built from source (C++ runtime via `CppCompile`, Java runtime via `Javac`, Python runtime/upb).

**Methodology:**
1. Module graph: run `bazel mod graph` (text + json) and `module_list.py`, then diff against 00. Run `bazel mod explain` for rules_kotlin, rules_rust, rules_jvm_external, rules_python, rules_pkg, rules_apple, jsoncpp, re2. Run `bazel mod show_extension @protobuf//...` for the non-dev extensions (maven, crate, prebuilt_protoc) to record which repos they generate.
2. Toolchain selection: run `bazel cquery //proto:greeting_proto --toolchain_resolution_debug=proto_toolchain_type` and note which protoc toolchain was picked.
3. Action graph per target T in {greeting_proto, greeting_cc_proto, greeting_java_proto, greeting_py_proto, greeting_cc_bin, greeting_java_bin}:
   - `bazel aquery 'deps(//proto:T)' --output=jsonproto | gzip > results/aquery_T.json.gz`
   - Run `summarize_aquery.py`. Record the protoc executable path, and count CppCompile actions in protobuf/abseil/zlib/etc. plus Javac actions for protobuf Java.
   - Run `fetched_repos.sh` after each target to see which modules that target makes Bazel download (for example, does `java_proto_library` download rules_kotlin or rules_jvm_external?).
4. Flip the prebuilt flag and repeat step 3 for greeting_proto and greeting_cc_proto:
   - v37: `--@protobuf//bazel/flags:prefer_prebuilt_protoc=false`
   - v33: `--@protobuf//bazel/toolchains:prefer_prebuilt_protoc=true`
   - Report the change in from-source actions.
5. Run `bazel help build | grep -i proto` and record the default for proto-related Bazel flags in 9.3.0, such as `--incompatible_enable_proto_toolchain_resolution` if it still exists.

**Expected / to confirm:**
- With prebuilt on, `proto_library` should need no CppCompile actions.
- `cc_proto_library` and `cc_binary` will still compile the C++ runtime (`//:protobuf` + abseil) from source, since no prebuilt C++ runtime exists.
- `java_proto_library` compiles `//java/core` from source with Javac.
- Count each of these.

---

## 03_minimal_proto_sbom: SBOM contents for the minimal project

**Contents:** a copy of 01 (protobuf 37.0-rc1), plus:
- In `MODULE.bazel`: `bazel_dep(name = "supply_chain_tools")` with `git_override(remote = "https://github.com/bazel-contrib/supply-chain", commit = <pinned main SHA, recorded in FINDINGS.md>, strip_prefix = "tools")`. `package_metadata` gets the same override (`strip_prefix = "metadata"`) so the versions match.
- `sbom/BUILD.bazel`: an `sbom` + `cyclonedx` + `spdx` triple (loads from `@supply_chain_tools//sbom:*.bzl`, `require_root_metadata = False`) for each of greeting_proto, greeting_cc_proto, greeting_java_proto, greeting_py_proto, greeting_cc_bin, greeting_java_bin.
- If 03's results show version-dependent behavior, an optional `03b` variant uses protobuf 33.4.

**What is tested:** whether the module-graph bloat (rules_kotlin, rules_rust, rules_jvm_external, rules_python, …) actually shows up in SBOMs, or whether the SBOM only reflects the target graph. Also checks the reverse: whether real shipped code (the protobuf runtime, abseil, zlib) is *missing* because those modules have no `package_metadata`.

**Methodology:**
1. `bazel build //sbom:all`. This is the only build in the plan, and it builds only the SBOM targets and the Go SBOM tool, not protobuf. Before building, run `bazel aquery 'deps(//sbom:all)'` to confirm that no protobuf CppCompile/Javac actions are in the requested outputs.
2. For each SBOM, keep `*.graph.json`, `*.sbom-classifications.json`, and the CycloneDX/SPDX outputs. Run `sbom_components.py` on them.
3. Cross-check by building the target directly with `--aspects=@supply_chain_tools//gather_metadata:gather_metadata.bzl%gather_metadata_info_and_write --output_groups=metadata` and diffing against the sbom rule's graph.
4. Compare for each target: SBOM components vs. the 01 module graph vs. the 01 fetched repos vs. the target-config `bazel cquery 'deps(T)'` repo set. Answer these explicitly:
   - Do rules_kotlin, rules_rust, or rules_jvm_external appear?
   - Does protoc (an exec-config tool) appear?
   - Do the protobuf runtime, abseil, and zlib appear?
5. Repeat for greeting_proto with the prebuilt flag off, to check whether toolchain choice changes the SBOM. Since exec deps are filtered, we expect no change.

---

## 04_grpc_java_minimal: does gRPC-Java force protobuf to be built from source?

This isolates hypothesis 2 outside Bazel's own large build.

**Contents:**
- `MODULE.bazel`: protobuf 37.0-rc1 (prebuilt on), `grpc-java` 1.71.0 (the version Bazel uses), rules_java, rules_jvm_external.
- If 1.71.0 doesn't resolve or analyze against protobuf 37, use protobuf 33.4 with `--@protobuf//bazel/toolchains:prefer_prebuilt_protoc=true` in `.bazelrc` instead, and note this in FINDINGS.md.
- `proto/greeter.proto`: one message and one `service`.
- `proto/BUILD.bazel`: `proto_library`, `java_proto_library`, and `java_grpc_library` (from `@grpc-java//:java_grpc_library.bzl`).

**What is tested:** whether adding `java_grpc_library` brings in a source-built protobuf C++ (libprotoc via `protoc-gen-grpc-java`, a `cc_binary`) even when protoc itself is prebuilt, and whether grpc-java brings in its own protobuf Java runtime (Maven jar) or compiles protobuf's `//java/core` from source.

**Methodology:**
1. Run `bazel mod graph`/`explain` for grpc-java and protobuf to check MVS-selected versions and whether grpc-java raises the protobuf version.
2. Run `aquery 'deps(...)'` + `summarize_aquery.py` on `java_proto_library` and on `java_grpc_library`. The difference in CppCompile actions in protobuf+/abseil-cpp+ is the cost added by gRPC.
3. Run `bazel cquery 'somepath(//proto:greeter_java_grpc, @protobuf//src/google/protobuf/compiler:code_generator)'` (adjust the label to whatever libprotoc is called in that version) and `allpaths(...)` to the grpc plugin target, to identify the edge responsible.
4. Run `bazel cquery 'kind("java_import|jvm_import", deps(//proto:greeter_java_grpc))'` and note whether `@maven//:com_google_protobuf_protobuf_java` and `@protobuf//java/core` are both present (two Java runtimes).

---

## 05_bazel_build: Bazel's own action graph

**Contents:**
- `checkout.sh`: `git clone --depth 1 --branch 9.3.0 https://github.com/bazelbuild/bazel bazel/`, which is gitignored. It then records Bazel's original `.bazelversion` and overwrites it with `9.3.0`.
- `run.sh` and `FINDINGS.md`. No Bazel sources are committed.

**What is tested:** which protobuf tools/runtimes Bazel's build uses prebuilt and which it compiles from source, and how much of the from-source work comes from (a) the prebuilt flag being off or the Java generator patch, (b) grpc-java's codegen plugin, (c) the grpc C++/upb dependency, or (d) the protobuf Java runtime.

**Methodology** (target `//src:bazel_nojdk`; also `//src:bazel` if analysis is cheap):
1. Run `bazel mod graph` + `module_list.py`. Run `bazel mod explain protobuf grpc grpc-java googleapis-grpc-java`. Record the effective protobuf version and that the patch is applied.
2. Run `bazel cquery //src:bazel_nojdk --toolchain_resolution_debug=proto_toolchain_type` to see which protoc is selected.
3. Run `bazel aquery 'deps(//src:bazel_nojdk)' --output=jsonproto | gzip` and `summarize_aquery.py`. Record:
   - the protoc executable used by GenProto actions (prebuilt or from source)
   - CppCompile counts per repo: protobuf+, abseil-cpp+, grpc+, grpc-java+, upb, re2, zlib
   - Javac actions for `@com_google_protobuf//java/core*`, compared with any Maven protobuf jars
4. Attribution queries (cquery, target config + exec):
   - `somepath(//src:bazel_nojdk, @com_google_protobuf//:protoc)` and the same toward the libprotoc library
   - `somepath(//src:bazel_nojdk, @grpc-java//compiler:grpc_java_plugin)`
   - `rdeps(deps(//src:bazel_nojdk), @com_google_protobuf//:protobuf, 1)`, to see which C++ code links the C++ runtime
   - `rdeps(deps(//src:bazel_nojdk), @com_google_protobuf//java/core:core, 1)`
   - Same checks for `@com_github_grpc_grpc//...`, to see whether grpc C++ is reachable at all.
5. Variant: rerun steps 2–3 with `--@com_google_protobuf//bazel/toolchains:prefer_prebuilt_protoc=true` and report the change. Whatever protobuf C++ compilation remains is attributable to grpc-java's plugin or other C++ consumers (step 4). Also note that this mode silently drops the `message.cc` generator patch, so Bazel can't simply turn the flag on without upstreaming that patch.
6. Optional variant, only if 5 leaves significant from-source work: temporarily edit Bazel's `MODULE.bazel` in the checkout to remove the protobuf patch, and check whether the patch blocks prebuilt use for any other reason. This edit is not committed.

---

## Deliverables and verification

- Each case: `run.sh` runs cleanly with Bazel 9.3.0 (checked via `bazel version` in `results/env.txt`). `FINDINGS.md` includes the module counts, the `mod explain` paths, the aquery summary tables, and the SBOM component lists.
- `RESULTS.md` at the top level answers each `investigation.md` question:
  1. Where the extra modules come from (protobuf vs. bazel_tools), and whether they're downloaded or only resolved.
  2. Whether they appear in supply-chain SBOMs.
  3. Which protobuf pieces are still built from source in the minimal project and in Bazel, and how much of that is due to gRPC(-Java) vs. the prebuilt flag/patch vs. unavoidable runtime compilation.
- Reproducibility: anyone can rerun `<case>/run.sh` from a clean checkout. `05` first needs `checkout.sh`.
