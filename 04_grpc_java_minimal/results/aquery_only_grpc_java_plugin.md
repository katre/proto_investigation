### deps(@grpc-java//compiler:grpc_java_plugin)

Total actions: **2925** (target config: 1408, exec config: 1517)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `protobuf+` | target | 839 | 269 | 96 | 96 | 0 | 0 | 0 |
| `protobuf+` | exec | 766 | 338 | 126 | 68 | 0 | 0 | 0 |
| `abseil-cpp+` | exec | 713 | 477 | 118 | 59 | 0 | 0 | 0 |
| `abseil-cpp+` | target | 538 | 358 | 60 | 60 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `zlib+` | target | 19 | 15 | 1 | 1 | 0 | 0 | 0 |
| `grpc-java+` | target | 9 | 2 | 0 | 1 | 0 | 0 | 0 |

protoc invocations (mnemonic, executable):

- 6 x `GenProto`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)
- 3 x `GenProtoDescriptorSet`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)

cc_binary targets built from source in protobuf/grpc repos:

- `@@grpc-java+//compiler:grpc_java_plugin` [target]
- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage0` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage1` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage0` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage1` [exec]

