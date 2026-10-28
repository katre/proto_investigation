### greeting_cc_proto_prebuilt_false

Total actions: **2882** (target config: 798, exec config: 2084)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `protobuf+` | exec | 1326 | 594 | 208 | 109 | 0 | 0 | 0 |
| `abseil-cpp+` | exec | 720 | 480 | 120 | 60 | 0 | 0 | 0 |
| `abseil-cpp+` | target | 528 | 354 | 58 | 58 | 0 | 0 | 0 |
| `protobuf+` | target | 242 | 65 | 16 | 16 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `zlib+` | target | 19 | 15 | 1 | 1 | 0 | 0 | 0 |
| `_main` | target | 6 | 1 | 1 | 1 | 0 | 0 | 0 |

protoc invocations (mnemonic, executable):

- 1 x `GenProto`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)
- 6 x `GenProtoDescriptorSet`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)

cc_binary targets built from source in protobuf/grpc repos:

- `@@protobuf+//:protoc` [exec]
- `@@protobuf+//src/google/protobuf/compiler/cpp:protoc-gen-cpp` [exec]
- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage0` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage0` [exec]

