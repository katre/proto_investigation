### deps(//sbom:all)

Total actions: **3262** (target config: 968, exec config: 2294)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `protobuf+` | exec | 1335 | 596 | 208 | 110 | 0 | 0 | 0 |
| `abseil-cpp+` | exec | 805 | 521 | 142 | 71 | 0 | 0 | 0 |
| `abseil-cpp+` | target | 528 | 354 | 58 | 58 | 0 | 0 | 0 |
| `protobuf+` | target | 348 | 65 | 16 | 16 | 2 | 2 | 0 |
| `_main` | target | 52 | 2 | 1 | 2 | 2 | 1 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `zlib+` | target | 19 | 15 | 1 | 1 | 0 | 0 | 0 |

protoc invocations (mnemonic, executable):

- 3 x `GenProto`: `bazel-out/k8-opt-exec/bin/external/protobuf+/bazel/flags/protoc` (FROM SOURCE)
- 17 x `GenProtoDescriptorSet`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)
- 15 x `ProtoCompile`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)
- 1 x `ProtobufCompileEditionDefaults`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)

cc_binary targets built from source in protobuf/grpc repos:

- `@@protobuf+//:protoc` [exec]
- `@@protobuf+//editions:internal_defaults_escape` [exec]
- `@@protobuf+//src/google/protobuf/compiler/cpp:protoc-gen-cpp` [exec]
- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage0` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage0` [exec]

