### greeting_cc_bin

Total actions: **2712** (target config: 766, exec config: 1946)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `protobuf+` | exec | 1188 | 540 | 184 | 97 | 0 | 0 | 0 |
| `abseil-cpp+` | exec | 720 | 480 | 120 | 60 | 0 | 0 | 0 |
| `abseil-cpp+` | target | 526 | 352 | 58 | 58 | 0 | 0 | 0 |
| `protobuf+` | target | 200 | 53 | 14 | 14 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `zlib+` | target | 19 | 15 | 1 | 1 | 0 | 0 | 0 |
| `_main` | target | 18 | 2 | 1 | 2 | 1 | 1 | 0 |

protoc invocations (mnemonic, executable):

- 2 x `GenProto`: `bazel-out/k8-opt-exec/bin/external/protobuf+/protoc` (FROM SOURCE)
- 1 x `GenProto`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)
- 4 x `GenProtoDescriptorSet`: `bazel-out/k8-opt-exec/bin/external/protobuf+/protoc` (FROM SOURCE)

cc_binary targets built from source in protobuf/grpc repos:

- `@@protobuf+//:protoc` [exec]
- `@@protobuf+//src/google/protobuf/compiler/cpp:protoc-gen-cpp` [exec]
- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage0` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage0` [exec]

