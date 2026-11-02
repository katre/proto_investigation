# Protobuf Rules Investigation

This repository investigates two problems the community has reported with the
[protobuf](https://github.com/protocolbuffers/protobuf) Bazel rules. The full
question is in [`investigation.md`](investigation.md), the test plan is in
[`PLAN.md`](PLAN.md), and the answers are in **[`RESULTS.md`](RESULTS.md)**.

## The questions

1. **Too many module dependencies.** protobuf depends on many modules,
   including language rules a project may not use (`rules_java`,
   `rules_kotlin`, `rules_rust`). Users ask "why do I depend on
   `rules_kotlin`?". There is also a theory that these deps leak into SBOMs
   generated with [bazel-contrib/supply-chain](https://github.com/bazel-contrib/supply-chain).
2. **Too much time building protobuf.** Bazel 9 can use a prebuilt protoc, but
   projects (Bazel itself among them) still spend a lot of time building
   protobuf. The suspected causes are:
   1. a protobuf runtime built from source, and
   2. the gRPC / gRPC-Java dependency forcing parts of protobuf to be built
      from source.

## Methodology

Each question is answered by a small, isolated test case in its own directory:

| case | what it tests |
|---|---|
| [`00_empty_baseline`](00_empty_baseline/FINDINGS.md) | what an empty Bazel 9.3.0 project already depends on and fetches |
| [`01_minimal_proto_v37`](01_minimal_proto_v37/FINDINGS.md) | one `.proto` file with protobuf 37.0-rc1 (C++, Java and Python rules) |
| [`02_minimal_proto_v33`](02_minimal_proto_v33/FINDINGS.md) | the same project with protobuf 33.4, the version built into Bazel 9.3.0 |
| [`03_minimal_proto_sbom`](03_minimal_proto_sbom/FINDINGS.md) | the 01 project plus supply-chain SBOMs |
| [`04_grpc_java_minimal`](04_grpc_java_minimal/FINDINGS.md) | the minimal project plus one `java_grpc_library` (grpc-java 1.71.0 and 1.84.0) |
| [`05_bazel_build`](05_bazel_build/FINDINGS.md) | Bazel 9.3.0's own build (`//src:bazel_nojdk`) |

How the cases are run:

- **Bazel 9.3.0, analysis only.** Everything uses `bazel mod`, `query`,
  `cquery` and `aquery`. The one exception is 03, which builds only the SBOM
  targets, not protobuf.
- **Clean state per run.** Each run uses a fresh output base, so the repos in
  `external/` are exactly the ones that run fetched. The `bazel mod` commands get
  their own output base because they fetch extra repos. User and system rc
  files are ignored, so only the case's own `.bazelrc` applies.
- **What is measured:**
  - Module graphs: counts, diffs against the baseline, and `mod explain` paths.
  - Repos actually fetched, as opposed to only resolved, plus their sizes.
  - Proto toolchain resolution.
  - `aquery 'deps(T)'` action counts by repo, mnemonic and configuration. These
    show whether protoc is prebuilt or built from source.
  - `somepath` attribution, to find which edge pulls in each from-source tool.
- **Variants:**
  - Each case is run with the `prefer_prebuilt_protoc` flag both on and off.
  - The 37.0-rc1 cases are also run with `native.bzl` patched (see below).
  - The grpc-java cases are also run with patched copies of grpc-java that
    take protoc from the proto toolchain and use the prebuilt
    `protoc-gen-grpc-java` plugin.

Each case has a `run.sh` that writes raw output to `results/` and a
`FINDINGS.md` that explains it. The shared scripts are in [`tools/`](tools/).

To reproduce a case, run `<case>/run.sh`. Case 05 needs
[`05_bazel_build/checkout.sh`](05_bazel_build/checkout.sh) first. The large
aquery `*.json.gz` outputs are gitignored, and `run.sh` regenerates them.

## Summary of results

See [`RESULTS.md`](RESULTS.md) for the details. In short:

- **Every Bazel 9.3.0 project already depends on protobuf 33.4, and through it
  on `rules_kotlin`.** It comes from `bazel_tools` (`MODULE.tools`). protobuf
  37.0-rc1 adds more modules, including a non-dev `rules_rust`. These modules
  aren't just resolved: toolchain resolution fetches every module that
  registers a toolchain.
- **The SBOM theory is wrong.** Module-graph deps don't appear in SBOMs. The
  real problem is the opposite: today the SBOMs are *empty*, because protobuf,
  abseil and zlib don't declare `package_metadata`.
- **protobuf is still built from source for several reasons:**
  - **37.0-rc1 regression:** the prebuilt protoc is never used on Bazel 9.
  - **33.4 needs an opt-in:** the prebuilt protoc is off by default, so users of
    Bazel's built-in version build protoc from source.
  - **`cc_proto_library`:** it always builds libprotoc (`protoc-gen-cpp`).
  - **`java_grpc_library` (hypothesis 2, confirmed):** it hard-codes a
    from-source protoc and builds its plugin from source.
  - **Runtimes (hypothesis 1):** the C++ runtime is built from source, but the
    Java runtime is cheap.
- **In Bazel's own build, gRPC-Java is not the cause.** Bazel's C++ code needs
  libprotoc on its own, through `cc_proto_library` and gRPC C++. A protobuf
  patch Bazel applies also blocks the prebuilt protoc.

## Recommendations

From [`RESULTS.md`](RESULTS.md#recommendations):

- **protobuf:**
  - Fix `bazel/private/native.bzl` in 37.0-rc1 (fall back to
    `proto_common_do_not_use`) before 37.0 final, so the prebuilt protoc is
    actually used on Bazel 9.
  - Have `cc_proto_library` use the prebuilt protoc's built-in `--cpp_out`
    when a prebuilt protoc is selected, instead of building `protoc-gen-cpp`.
- **Bazel:** bump `bazel_tools` to a protobuf release whose prebuilt-protoc
  default works.
- **grpc-java and grpc:**
  - Make `java_grpc_library` and `cc_grpc_library` use the proto toolchain's
    protoc.
  - Offer prebuilt codegen plugins. grpc-java already publishes them on Maven
    Central.
- **protobuf and other rules authors:** keep language rules out of protobuf's
  non-dev deps. Alternatively, register toolchains from small repos that don't
  hold the payload, so users stop fetching every module that registers a
  toolchain.
- **Module authors (protobuf, abseil, zlib, …):** adopt `package_metadata`
  (`REPO.bazel` `default_package_metadata`) so that SBOMs list the code that
  actually ships.
- **Bazel and protobuf:** get Bazel's `message.cc` Java-generator patch into a
  protobuf release, so Bazel can use the prebuilt protoc.
