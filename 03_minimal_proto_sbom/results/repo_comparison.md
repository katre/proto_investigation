# Repos per target: SBOM traversal vs configured graph

`traversal` = repos with targets the gather_metadata aspect visits (upper bound for
the SBOM). `cquery target` / `cquery exec` = repos with targets in `deps(T)` by
configuration. Source files (null config) are not counted.

## greeting_proto

- traversal (2): (main), protobuf+
- cquery target (5): (main), platforms, protobuf+, rules_license+, zlib+
- cquery exec only (5): abseil-cpp+, bazel_tools, bazel_tools+xcode_configure_extension+local_config_xcode, rules_cc+, rules_cc++cc_configure_extension+local_config_cc
- cquery target but not traversed: platforms, rules_license+, zlib+

## greeting_cc_proto

- traversal (4): (main), abseil-cpp+, protobuf+, zlib+
- cquery target (10): (main), abseil-cpp+, bazel_tools, bazel_tools+xcode_configure_extension+local_config_xcode, platforms, protobuf+, rules_cc+, rules_cc++cc_configure_extension+local_config_cc, rules_license+, zlib+
- cquery exec only (0): 
- cquery target but not traversed: bazel_tools, bazel_tools+xcode_configure_extension+local_config_xcode, platforms, rules_cc+, rules_cc++cc_configure_extension+local_config_cc, rules_license+

## greeting_java_proto

- traversal (4): (main), bazel_tools, protobuf+, rules_java+
- cquery target (9): (main), bazel_tools, platforms, protobuf+, protobuf++protoc+prebuilt_protoc.linux_x86_64, rules_java+, rules_java++toolchains+local_jdk, rules_license+, zlib+
- cquery exec only (10): abseil-cpp+, bazel_tools+xcode_configure_extension+local_config_xcode, rules_cc+, rules_cc++cc_configure_extension+local_config_cc, rules_java++toolchains+remote_java_tools, rules_java++toolchains+remote_java_tools_linux, rules_java++toolchains+remotejdk11_linux, rules_java++toolchains+remotejdk25_linux, rules_python+, rules_python++python+python_3_11_x86_64-unknown-linux-gnu
- cquery target but not traversed: platforms, protobuf++protoc+prebuilt_protoc.linux_x86_64, rules_java++toolchains+local_jdk, rules_license+, zlib+

## greeting_py_proto

- traversal (2): (main), protobuf+
- cquery target (9): (main), bazel_tools, platforms, protobuf+, protobuf++protoc+prebuilt_protoc.linux_x86_64, rules_license+, rules_python+, rules_python++python+python_3_11_x86_64-unknown-linux-gnu, zlib+
- cquery exec only (4): abseil-cpp+, bazel_tools+xcode_configure_extension+local_config_xcode, rules_cc+, rules_cc++cc_configure_extension+local_config_cc
- cquery target but not traversed: bazel_tools, platforms, protobuf++protoc+prebuilt_protoc.linux_x86_64, rules_license+, rules_python+, rules_python++python+python_3_11_x86_64-unknown-linux-gnu, zlib+

## greeting_cc_bin

- traversal (6): (main), abseil-cpp+, bazel_tools, protobuf+, rules_cc+, zlib+
- cquery target (10): (main), abseil-cpp+, bazel_tools, bazel_tools+xcode_configure_extension+local_config_xcode, platforms, protobuf+, rules_cc+, rules_cc++cc_configure_extension+local_config_cc, rules_license+, zlib+
- cquery exec only (0): 
- cquery target but not traversed: bazel_tools+xcode_configure_extension+local_config_xcode, platforms, rules_cc++cc_configure_extension+local_config_cc, rules_license+

## greeting_java_bin

- traversal (4): (main), bazel_tools, protobuf+, rules_java+
- cquery target (12): (main), bazel_tools, bazel_tools+xcode_configure_extension+local_config_xcode, platforms, protobuf+, protobuf++protoc+prebuilt_protoc.linux_x86_64, rules_cc+, rules_cc++cc_configure_extension+local_config_cc, rules_java+, rules_java++toolchains+local_jdk, rules_license+, zlib+
- cquery exec only (7): abseil-cpp+, rules_java++toolchains+remote_java_tools, rules_java++toolchains+remote_java_tools_linux, rules_java++toolchains+remotejdk11_linux, rules_java++toolchains+remotejdk25_linux, rules_python+, rules_python++python+python_3_11_x86_64-unknown-linux-gnu
- cquery target but not traversed: bazel_tools+xcode_configure_extension+local_config_xcode, platforms, protobuf++protoc+prebuilt_protoc.linux_x86_64, rules_cc+, rules_cc++cc_configure_extension+local_config_cc, rules_java++toolchains+local_jdk, rules_license+, zlib+

