# Sourced by each test case's run.sh.
#
# Every run uses a fresh output base instead of `bazel clean --expunge`, so that
# $(output_base)/external only contains what that run fetched. The repository
# cache (under the output user root) is shared between runs. User/system rc
# files are ignored so only the test case's own .bazelrc applies.
set -euo pipefail
CASE="$(basename "$(pwd)")"
TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#
# `bazel mod` commands fetch the repos of many modules in the graph (e.g. an
# empty project's `mod graph` fetches rules_kotlin), so they get their own
# output base (B_MOD) and never pollute the "fetched" lists recorded with B.
STAMP="$(date +%s)"
OUTPUT_BASE="${OUTPUT_BASE:-/tmp/proto_investigation_ob/${CASE}-${STAMP}}"
STARTUP=(--nohome_rc --nosystem_rc "--output_base=${OUTPUT_BASE}" --max_idle_secs=600)
B=(bazel "${STARTUP[@]}")
B_MOD=(bazel --nohome_rc --nosystem_rc "--output_base=${OUTPUT_BASE}-mod" --max_idle_secs=600)
R=results
mkdir -p "$R"

record_env() {
  { "${B[@]}" version 2>/dev/null; uname -m; echo "output_base: ${OUTPUT_BASE}"; } > "$R/env.txt"
}

fetched() {
  "$TOOLS/fetched_repos.sh" "${STARTUP[@]}" > "$R/$1"
}

sizes() {
  "$TOOLS/repo_sizes.sh" "${STARTUP[@]}" > "$R/$1"
}
