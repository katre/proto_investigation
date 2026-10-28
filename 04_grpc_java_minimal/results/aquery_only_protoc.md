### deps(@protobuf//:protoc)

Total actions: **2800** (target config: 1387, exec config: 1413)

| repo | config | all actions | CppCompile | CppArchive | CppLink | Javac | Turbine | JavaIjar |
|---|---|---|---|---|---|---|---|---|
| `protobuf+` | target | 827 | 266 | 93 | 94 | 0 | 0 | 0 |
| `abseil-cpp+` | exec | 713 | 477 | 118 | 59 | 0 | 0 | 0 |
| `protobuf+` | exec | 662 | 286 | 110 | 58 | 0 | 0 | 0 |
| `abseil-cpp+` | target | 538 | 358 | 60 | 60 | 0 | 0 | 0 |
| `zlib+` | exec | 35 | 30 | 2 | 1 | 0 | 0 | 0 |
| `zlib+` | target | 19 | 15 | 1 | 1 | 0 | 0 | 0 |

cc_binary targets built from source in protobuf/grpc repos:

- `@@protobuf+//:protoc` [target]
- `@@protobuf+//src/google/protobuf/compiler:protoc_minimal` [exec]
- `@@protobuf+//upb_generator/c:protoc-gen-upb_stage0` [exec]
- `@@protobuf+//upb_generator/minitable:protoc-gen-upb_minitable_stage0` [exec]

