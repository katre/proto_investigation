### bazel_nojdk_prebuilt

Total actions: **9895** (target config: 6754, exec config: 3141)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `_main` | target | 3420 | 57 | 31 | 40 | 948 | 929 | 18 |
| `protobuf+` | exec | 1690 | 660 | 260 | 138 | 2 | 2 | 0 |
| `grpc+` | target | 1380 | 518 | 278 | 278 | 0 | 0 | 0 |
| `abseil-cpp+` | exec | 783 | 511 | 136 | 68 | 0 | 0 | 0 |
| `protobuf+` | target | 696 | 148 | 75 | 75 | 3 | 3 | 0 |
| `abseil-cpp+` | target | 666 | 432 | 78 | 78 | 0 | 0 | 0 |
| `_main` | exec | 281 | 2 | 0 | 1 | 79 | 53 | 1 |
| `zstd-jni+` | exec | 98 | 84 | 0 | 1 | 1 | 1 | 0 |
| `c-ares+` | target | 94 | 91 | 1 | 0 | 0 | 0 | 0 |
| `googleapis+` | target | 82 | 6 | 6 | 6 | 13 | 13 | 0 |
| `zstd-jni+` | target | 56 | 42 | 0 | 1 | 1 | 1 | 0 |
| `grpc-java+` | target | 38 | 0 | 0 | 0 | 13 | 9 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `grpc+` | exec | 34 | 18 | 4 | 3 | 0 | 0 | 0 |
| `bazel_tools` | exec | 32 | 2 | 0 | 1 | 0 | 0 | 0 |
| `re2+` | target | 25 | 22 | 1 | 1 | 0 | 0 | 0 |
| `xds+` | target | 22 | 4 | 4 | 4 | 0 | 0 | 0 |
| `remoteapis+` | target | 20 | 0 | 0 | 0 | 5 | 5 | 0 |
| `blake3+` | target | 20 | 7 | 5 | 4 | 0 | 0 | 0 |
| `zlib+` | target | 19 | 15 | 1 | 1 | 0 | 0 | 0 |
| `rules_jvm_external+` | exec | 16 | 0 | 0 | 0 | 3 | 2 | 0 |
| `grpc-java+` | exec | 11 | 4 | 0 | 1 | 0 | 0 | 0 |
| `protoc-gen-validate+` | target | 11 | 2 | 2 | 2 | 0 | 0 | 0 |

protoc invocations (mnemonic, executable):

- 7 x `Action`: `bazel-out/default_host_platform-opt-exec/bin/external/protobuf+/protoc` (FROM SOURCE)
- 129 x `GenProto`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)
- 91 x `GenProtoDescriptorSet`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)
- 2 x `ProtoCompile`: `external/protobuf++protoc+prebuilt_protoc.linux_x86_64/bin/protoc` (PREBUILT)

cc_binary targets built from source in protobuf/grpc repos:

- `@@grpc+//src/compiler:grpc_cpp_plugin_native` [exec]
- `@@grpc-java+//compiler:grpc_java_plugin` [exec]
- `@@protobuf+//:protoc` [exec]
- `@@protobuf+//src/google/protobuf/compiler/cpp:protoc-gen-cpp` [exec]
- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage0` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage1` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage0` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage1` [exec]
- `@@protobuf+//upb_generator/reflection:protoc-gen-upbdefs` [exec]

