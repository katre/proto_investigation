"""Records every target that supply-chain's gather_metadata_info aspect visits.

This mirrors gather_metadata_info_common() from
@supply_chain_tools//gather_metadata:core.bzl: the same exec-config cutoff
and the same should_traverse() attribute filter. The difference is that it
records every visited target, whether or not that target has package
metadata. So the output is the most an SBOM could contain if every module
declared package_metadata.

Usage:
  bazel build //proto:T --aspects=//probe:traversal.bzl%sbom_traversal \
      --output_groups=sbom_traversal
"""

load("@supply_chain_tools//gather_metadata:core.bzl", "should_traverse")

_TraversalInfo = provider(fields = ["labels"])

def _is_exec_config(ctx):
    # Copy of the private helper in core.bzl (is_tool_configuration() is
    # public in Bazel 9, so the bazel_features check is dropped).
    if ctx.configuration.is_tool_configuration():
        return True
    return ctx.bin_dir.path.endswith("-exec/bin") or "-exec-" in ctx.bin_dir.path

def _deps(attr_value):
    if type(attr_value) == "Target":
        return [attr_value]
    if type(attr_value) == type([]):
        return [v for v in attr_value if type(v) == "Target"]
    if type(attr_value) == type({}):
        out = []
        for k, v in attr_value.items():
            for e in (k, v):
                if type(e) == "Target":
                    out.append(e)
                elif type(e) == type([]):
                    out.extend([i for i in e if type(i) == "Target"])
        return out
    return []

def _sbom_traversal_impl(target, ctx):
    if _is_exec_config(ctx):
        return [_TraversalInfo(labels = depset())]
    transitive = []
    for name in dir(ctx.rule.attr):
        if not should_traverse(ctx, name):
            continue
        for dep in _deps(getattr(ctx.rule.attr, name)):
            if _TraversalInfo in dep:
                transitive.append(dep[_TraversalInfo].labels)
    labels = depset([str(target.label)], transitive = transitive)
    out = ctx.actions.declare_file(ctx.label.name + ".sbom_traversal.txt")
    ctx.actions.write(out, "\n".join(sorted(labels.to_list())) + "\n")
    return [
        _TraversalInfo(labels = labels),
        OutputGroupInfo(sbom_traversal = depset([out])),
    ]

sbom_traversal = aspect(
    implementation = _sbom_traversal_impl,
    attr_aspects = ["*"],
    apply_to_generating_rules = True,
)
