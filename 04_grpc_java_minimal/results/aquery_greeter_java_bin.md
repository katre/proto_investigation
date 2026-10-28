### greeter_java_bin

Total actions: **2430** (target config: 125, exec config: 2305)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `protobuf+` | exec | 1479 | 660 | 240 | 126 | 0 | 0 | 0 |
| `abseil-cpp+` | exec | 720 | 480 | 120 | 60 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `protobuf+` | target | 33 | 0 | 0 | 0 | 2 | 2 | 0 |
| `_main` | target | 18 | 0 | 0 | 0 | 3 | 2 | 0 |
| `grpc-java+` | target | 18 | 0 | 0 | 0 | 7 | 4 | 0 |
| `rules_jvm_external+` | exec | 16 | 0 | 0 | 0 | 3 | 2 | 0 |
| `grpc-java+` | exec | 11 | 4 | 0 | 1 | 0 | 0 | 0 |

protoc invocations (mnemonic, executable):

- 1 x `Action`: `bazel-out/k8-opt-exec/bin/external/protobuf+/protoc` (FROM SOURCE)
- 7 x `GenProto`: `bazel-out/k8-opt-exec/bin/external/protobuf+/bazel/flags/protoc` (FROM SOURCE)
- 17 x `GenProtoDescriptorSet`: `bazel-out/k8-opt-exec/bin/external/protobuf+/src/google/protobuf/compiler/protoc_minimal` (FROM SOURCE)
- 1 x `ProtoCompile`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)

cc_binary targets built from source in protobuf/grpc repos:

- `@@grpc-java+//compiler:grpc_java_plugin` [exec]
- `@@protobuf+//:protoc` [exec]
- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage0` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage1` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage0` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage1` [exec]

