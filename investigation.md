# Protobuf Rules Investigation

There are a number of related issues the community has reported with the current
protobuf rules (https://github.com/protocolbuffers/protobuf) with Bazel.

## Problems with protobuf rules

### Too many module dependencies

The protobuf rules depend on many other modules (see version 37.0-rc1,
https://registry.bazel.build/modules/protobuf/37.0-rc1/, which depends on 17
other modules). These include some language-specific modules which projects may
not themselves need, such as `rules_java`, `rules_kotlin`, or `rules_rust`.

Users frequently ask "Why do I have a dependency on the `rules_kotlin` module?".

#### SBOM generation

There is a theory that this is also impacting SBOM generation (via
`https://github.com/bazel-contrib/supply-chain`). We need to investigate whether
this is actually the case in various circumstances.

### Too much time building protobuf

A major advance in Bazel 9 was using precompiled protobuf tools when possible,
which was supposed to reduce the amount of time spent building protobuf for
projects that use protobuf. However, we are still seeing large amount of build
time spent building something from protobuf when building projects that use it
(such as Google itself).

Possibilities for this are:
1. Bazel links a protobuf runtime in order to read and process proto files. This
   runtime might be built from source instead of from a probuilt archive.
2. Bazel depends on GRPC (and, specifically, on GRPC-Java), which has a complex
   relationship with protobuf. Bazel may be building parts of protobuf from
   source because of the GRPC dependency.

## Investigation

Run the following investigations and report what issues are found.

### Minimal project

Create a simple project with one proto file, examine how many dependencies that
pulls in, and what is visible from that. Check the action graph via `bazel
aquery` to see what protobuf binaries are being built from source.

#### Minimal project SBOM

Take the same minimal project, add SBOM generation via the `supply-chain` rules,
and check what bazel modules appear in the resulting SBOM.

### Bazel build

Check bazel's action graph, see what protobuf tools/runtimes are used from
precompiled binaries and which are built from source. Check whether the GRPC
dependency is influencing this.
