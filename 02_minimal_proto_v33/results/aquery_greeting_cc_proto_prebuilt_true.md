### greeting_cc_proto_prebuilt_true

Total actions: **1879** (target config: 754, exec config: 1125)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `abseil-cpp+` | exec | 713 | 477 | 118 | 59 | 0 | 0 | 0 |
| `abseil-cpp+` | target | 526 | 352 | 58 | 58 | 0 | 0 | 0 |
| `protobuf+` | exec | 374 | 162 | 40 | 21 | 0 | 0 | 0 |
| `protobuf+` | target | 200 | 53 | 14 | 14 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `zlib+` | target | 19 | 15 | 1 | 1 | 0 | 0 | 0 |
| `_main` | target | 6 | 1 | 1 | 1 | 0 | 0 | 0 |

protoc invocations (mnemonic, executable):

- 1 x `GenProto`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)
- 4 x `GenProtoDescriptorSet`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)

cc_binary targets built from source in protobuf/grpc repos:

- `@@protobuf+//src/google/protobuf/compiler/cpp:protoc-gen-cpp` [exec]

