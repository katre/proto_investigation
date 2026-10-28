### greeting_py_proto

Total actions: **2260** (target config: 81, exec config: 2179)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `protobuf+` | exec | 1326 | 594 | 208 | 109 | 0 | 0 | 0 |
| `abseil-cpp+` | exec | 805 | 521 | 142 | 71 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |

protoc invocations (mnemonic, executable):

- 1 x `GenProto`: `bazel-out/k8-opt-exec/bin/external/protobuf+/bazel/flags/protoc` (FROM SOURCE)
- 2 x `GenProtoDescriptorSet`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)
- 14 x `ProtoCompile`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)
- 1 x `ProtobufCompileEditionDefaults`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)

cc_binary targets built from source in protobuf/grpc repos:

- `@@protobuf+//:protoc` [exec]
- `@@protobuf+//editions:internal_defaults_escape` [exec]
- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage0` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage0` [exec]

