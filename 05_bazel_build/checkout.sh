#!/bin/bash
# Clones Bazel 9.3.0 into ./bazel (gitignored) and pins it to build with
# Bazel 9.3.0. Bazel's own .bazelversion is saved in results/.
set -euo pipefail
cd "$(dirname "$0")"
rm -rf bazel
git clone -q --depth 1 --branch 9.3.0 https://github.com/bazelbuild/bazel bazel
mkdir -p results
{ echo "bazel checkout: $(git -C bazel rev-parse HEAD) (tag 9.3.0)"; echo "original .bazelversion: $(cat bazel/.bazelversion 2>/dev/null || echo '(none)')"; } > results/checkout.txt
echo 9.3.0 > bazel/.bazelversion
