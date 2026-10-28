### greeting_py_proto

Total actions: **2124** (target config: 83, exec config: 2041)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `protobuf+` | exec | 1188 | 540 | 184 | 97 | 0 | 0 | 0 |
| `abseil-cpp+` | exec | 805 | 521 | 142 | 71 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `_main` | target | 10 | 1 | 1 | 1 | 1 | 1 | 0 |

protoc invocations (mnemonic, executable):

- 1 x `Action`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)
- 2 x `GenProto`: `bazel-out/k8-opt-exec/bin/external/protobuf+/protoc` (FROM SOURCE)
- 1 x `GenProto`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)
- 2 x `GenProtoDescriptorSet`: `bazel-out/k8-opt-exec/bin/external/protobuf+/protoc` (FROM SOURCE)
- 12 x `ProtoCompile`: `bazel-out/k8-opt-exec/bin/external/protobuf+/protoc` (FROM SOURCE)

cc_binary targets built from source in protobuf/grpc repos:

- `@@protobuf+//:protoc` [exec]
- `@@protobuf+//editions:internal_defaults_escape` [exec]
- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage0` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage0` [exec]

