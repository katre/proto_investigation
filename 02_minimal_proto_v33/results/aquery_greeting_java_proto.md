### greeting_java_proto

Total actions: **2014** (target config: 46, exec config: 1968)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `protobuf+` | exec | 1179 | 538 | 184 | 96 | 0 | 0 | 0 |
| `abseil-cpp+` | exec | 720 | 480 | 120 | 60 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `protobuf+` | target | 34 | 0 | 0 | 0 | 2 | 2 | 0 |
| `bazel_tools` | exec | 24 | 2 | 0 | 1 | 0 | 0 | 0 |
| `_main` | target | 9 | 1 | 1 | 1 | 1 | 1 | 0 |

protoc invocations (mnemonic, executable):

- 1 x `GenProto`: `bazel-out/k8-opt-exec/bin/external/protobuf+/protoc` (FROM SOURCE)
- 1 x `GenProto`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)
- 14 x `GenProtoDescriptorSet`: `bazel-out/k8-opt-exec/bin/external/protobuf+/protoc` (FROM SOURCE)
- 1 x `ProtoCompile`: `bazel-out/k8-opt-exec/bin/external/protobuf+/protoc` (FROM SOURCE)

cc_binary targets built from source in protobuf/grpc repos:

- `@@protobuf+//:protoc` [exec]
- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage0` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage0` [exec]

