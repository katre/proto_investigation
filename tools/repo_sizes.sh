#!/bin/bash
# Prints the on-disk size (KiB, following the repo contents cache symlinks) of
# every fetched external repository, largest first. Local repositories
# (local_jdk, local_config_*) are skipped since they aren't downloads.
# Usage: repo_sizes.sh [bazel startup options...]
set -euo pipefail
output_base="$(bazel "$@" info output_base 2>/dev/null)"
cd "${output_base}/external"
for r in *; do
  [[ "$r" == *.marker || "$r" == _main || "$r" == bazel_tools || "$r" == *local_jdk || "$r" == *local_config_* ]] && continue
  [[ -d "$r" ]] || continue
  printf '%s\t%s\n' "$(du -skL "$r" 2>/dev/null | cut -f1)" "$r"
done | sort -rn
