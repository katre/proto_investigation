#!/bin/bash
# Records the module graph Bazel 9.3.0 imposes on a project with no protobuf usage.
cd "$(dirname "$0")"
source ../tools/common.sh
record_env

# Analysis first, in a pristine output base.
"${B[@]}" query //... > "$R/query.txt" 2>/dev/null
fetched fetched_after_query.txt
# A filegroup needs no toolchains.
"${B[@]}" build --nobuild //:hello 2>/dev/null
fetched fetched_after_analysis_filegroup.txt
# A cc_library needs C++ toolchain resolution, which loads every registered
# toolchain in the module graph.
"${B[@]}" build --nobuild //cc:answer --toolchain_resolution_debug=.* > "$R/toolchain_resolution_cc.txt" 2>&1
fetched fetched_after_analysis_cc_library.txt
sizes fetched_sizes_kib.txt

# Module graph inspection (separate output base, see common.sh).
"${B_MOD[@]}" mod graph > "$R/mod_graph.txt" 2>/dev/null
"${B_MOD[@]}" mod graph --include_builtin > "$R/mod_graph_builtin.txt" 2>/dev/null
"${B_MOD[@]}" mod graph --include_builtin --output=json > "$R/mod_graph_builtin.json" 2>/dev/null
python3 "$TOOLS/module_list.py" "$R/mod_graph_builtin.json" > "$R/modules.txt"
for m in rules_kotlin rules_jvm_external rules_python rules_java rules_rust protobuf; do
  echo "### $m"
  "${B_MOD[@]}" mod explain --include_builtin "$m" 2>/dev/null || echo "($m is not in the module graph)"
done > "$R/mod_explain.txt"
"$TOOLS/fetched_repos.sh" "${B_MOD[@]:1}" > "$R/fetched_by_mod_commands.txt"
