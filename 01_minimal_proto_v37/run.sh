#!/bin/bash
# protobuf 37.0-rc1: prefer_prebuilt_protoc defaults to true.
cd "$(dirname "$0")"
exec ../tools/run_minimal_proto.sh @protobuf//bazel/flags:prefer_prebuilt_protoc false
