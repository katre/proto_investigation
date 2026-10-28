### greeter_proto

Total actions: **1143** (target config: 1, exec config: 1142)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `abseil-cpp+` | exec | 713 | 477 | 118 | 59 | 0 | 0 | 0 |
| `protobuf+` | exec | 391 | 158 | 46 | 24 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |

protoc invocations (mnemonic, executable):

- 1 x `GenProtoDescriptorSet`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)

cc_binary targets built from source in protobuf/grpc repos:

- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]

