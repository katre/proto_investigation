#!/bin/bash
# Lists the external repositories that have actually been fetched (i.e. exist
# under $(bazel info output_base)/external), one per line, sorted.
# Usage: fetched_repos.sh [bazel startup options...]
set -euo pipefail
output_base="$(bazel "$@" info output_base 2>/dev/null)"
if [[ ! -d "${output_base}/external" ]]; then
  exit 0
fi
find "${output_base}/external" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -printf '%f\n' | sort
