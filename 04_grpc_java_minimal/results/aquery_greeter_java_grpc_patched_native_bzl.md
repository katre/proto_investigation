### greeter_java_grpc_patched_native_bzl

Total actions: **2406** (target config: 105, exec config: 2301)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `protobuf+` | exec | 1475 | 660 | 240 | 126 | 0 | 0 | 0 |
| `abseil-cpp+` | exec | 720 | 480 | 120 | 60 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `protobuf+` | target | 34 | 0 | 0 | 0 | 2 | 2 | 0 |
| `grpc-java+` | target | 18 | 0 | 0 | 0 | 7 | 4 | 0 |
| `rules_jvm_external+` | exec | 16 | 0 | 0 | 0 | 3 | 2 | 0 |
| `grpc-java+` | exec | 11 | 4 | 0 | 1 | 0 | 0 | 0 |
| `_main` | target | 8 | 0 | 0 | 0 | 2 | 2 | 0 |

protoc invocations (mnemonic, executable):

- 1 x `Action`: `bazel-out/k8-opt-exec/bin/external/protobuf+/protoc` (FROM SOURCE)
- 7 x `GenProto`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)
- 17 x `GenProtoDescriptorSet`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)
- 1 x `ProtoCompile`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)

cc_binary targets built from source in protobuf/grpc repos:

- `@@grpc-java+//compiler:grpc_java_plugin` [exec]
- `@@protobuf+//:protoc` [exec]
- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage0` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage1` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage0` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage1` [exec]

