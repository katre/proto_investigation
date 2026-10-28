### greeting_cc_proto_patched_native_bzl

Total actions: **1980** (target config: 799, exec config: 1181)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `abseil-cpp+` | exec | 713 | 477 | 118 | 59 | 0 | 0 | 0 |
| `abseil-cpp+` | target | 528 | 354 | 58 | 58 | 0 | 0 | 0 |
| `protobuf+` | exec | 430 | 188 | 44 | 23 | 0 | 0 | 0 |
| `protobuf+` | target | 243 | 65 | 16 | 16 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `zlib+` | target | 19 | 15 | 1 | 1 | 0 | 0 | 0 |
| `_main` | target | 6 | 1 | 1 | 1 | 0 | 0 | 0 |

protoc invocations (mnemonic, executable):

- 1 x `GenProto`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)
- 6 x `GenProtoDescriptorSet`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)

cc_binary targets built from source in protobuf/grpc repos:

- `@@protobuf+//src/google/protobuf/compiler/cpp:protoc-gen-cpp` [exec]

