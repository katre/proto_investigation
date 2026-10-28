### greeting_java_proto

Total actions: **2150** (target config: 45, exec config: 2105)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `protobuf+` | exec | 1317 | 592 | 208 | 108 | 0 | 0 | 0 |
| `abseil-cpp+` | exec | 720 | 480 | 120 | 60 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `protobuf+` | target | 33 | 0 | 0 | 0 | 2 | 2 | 0 |
| `_main` | target | 9 | 1 | 1 | 1 | 1 | 1 | 0 |

protoc invocations (mnemonic, executable):

- 2 x `GenProto`: `bazel-out/k8-opt-exec/bin/external/protobuf+/bazel/flags/protoc` (FROM SOURCE)
- 14 x `GenProtoDescriptorSet`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)
- 1 x `ProtoCompile`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)

cc_binary targets built from source in protobuf/grpc repos:

- `@@protobuf+//:protoc` [exec]
- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage0` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage0` [exec]

