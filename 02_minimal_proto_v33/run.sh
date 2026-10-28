#!/bin/bash
# protobuf 33.4 (the version bazel_tools depends on): prefer_prebuilt_protoc defaults to false.
cd "$(dirname "$0")"
exec ../tools/run_minimal_proto.sh @protobuf//bazel/toolchains:prefer_prebuilt_protoc true
