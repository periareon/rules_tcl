"""TCL Lint rules"""

load("@rules_venv//python:py_info.bzl", "PyInfo")
load("//tcl/private:providers.bzl", "TclInfo")
load("//tcl/private:toolchain.bzl", "TOOLCHAIN_TYPE")

def _current_tcl_tclint_toolchain_impl(ctx):
    toolchain = ctx.toolchains[TOOLCHAIN_TYPE]
    tclint = toolchain.tclint
    if not tclint:
        fail("`tclint` was not provided for the toolchain in the current configuration: {}".format(
            toolchain.label,
        ))

    if PyInfo not in tclint:
        fail("`tclint` is required to be a `py_library` target which produces `PyInfo`. `{}` does not do this. Please update `{}`".format(
            tclint.label,
            toolchain.label,
        ))

    return [
        DefaultInfo(
            files = tclint[DefaultInfo].files,
            runfiles = tclint[DefaultInfo].default_runfiles,
        ),
        tclint[PyInfo],
        tclint[OutputGroupInfo],
        tclint[InstrumentedFilesInfo],
    ]

current_tcl_tclint_toolchain = rule(
    doc = "A rule for accessing the `tclint` attribute of the current `tcl_toolchain`.",
    implementation = _current_tcl_tclint_toolchain_impl,
    toolchains = [TOOLCHAIN_TYPE],
)

def find_srcs(target):
    """Find all lintable source files for a given target.

    Note that generated files and pkgIndex.tcl files are ignored.

    Args:
        target (Target): The target to collect from.

    Returns:
        depset[File]: A depset of lintable source files.
    """
    if TclInfo not in target:
        return []

    # Ignore any external targets
    if target.label.workspace_root.startswith("external"):
        return []

    info = target[TclInfo]

    return [
        src
        for src in info.srcs.to_list()
        if src.is_source
    ]

def _tcl_lint_aspect_impl(target, ctx):
    srcs = find_srcs(target)
    if not srcs:
        return []

    ignore_tags = [
        "no_tcl_lint",
        "no_lint",
        "nolint",
    ]
    for tag in ctx.rule.attr.tags:
        sanitized = tag.replace("-", "_").lower()
        if sanitized in ignore_tags:
            return []

    lint_srcs = [src for src in srcs if src.basename != "pkgIndex.tcl"]

    config = ctx.file._config
    output = ctx.actions.declare_file("{}.tclint.ok".format(target.label.name))

    args = ctx.actions.args()
    args.add_all(lint_srcs, format_each = "--src=%s")
    args.add("--config", config)
    args.add("--marker", output)

    ctx.actions.run(
        mnemonic = "TclLint",
        executable = ctx.executable._linter,
        arguments = [args],
        inputs = depset(lint_srcs + [config]),
        progress_message = "TclLint %{label}",
        outputs = [output],
    )

    return [OutputGroupInfo(
        tcl_lint_checks = depset([output]),
    )]

tcl_lint_aspect = aspect(
    doc = "An aspect for performing lint+formatting checks on Tcl targets.",
    implementation = _tcl_lint_aspect_impl,
    attrs = {
        "_config": attr.label(
            allow_single_file = True,
            default = Label("//tcl/settings:tclint_config"),
        ),
        "_linter": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//tcl/private/linting:linter"),
        ),
    },
    required_providers = [TclInfo],
)

def _tcl_format_aspect_impl(target, ctx):
    srcs = find_srcs(target)
    if not srcs:
        return []

    ignore_tags = [
        "no_tcl_format",
        "no_tclformat",
        "no_tclfmt",
        "noformat",
        "nofmt",
    ]
    for tag in ctx.rule.attr.tags:
        sanitized = tag.replace("-", "_").lower()
        if sanitized in ignore_tags:
            return []

    config = ctx.file._config
    output = ctx.actions.declare_file("{}.tclfmt.ok".format(target.label.name))

    args = ctx.actions.args()
    args.add_all(srcs, format_each = "--src=%s")
    args.add("--config", config)
    args.add("--marker", output)

    ctx.actions.run(
        mnemonic = "TclFormat",
        executable = ctx.executable._formatter,
        arguments = [args],
        inputs = depset(srcs + [config]),
        progress_message = "TclFormat %{label}",
        outputs = [output],
    )

    return [OutputGroupInfo(
        tcl_format_checks = depset([output]),
    )]

tcl_format_aspect = aspect(
    doc = "An aspect for performing formatting checks on Tcl targets.",
    implementation = _tcl_format_aspect_impl,
    attrs = {
        "_config": attr.label(
            allow_single_file = True,
            default = Label("//tcl/settings:tclint_config"),
        ),
        "_formatter": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//tcl/private/linting:format_checker"),
        ),
    },
    required_providers = [TclInfo],
)

def _rlocationpath(file, workspace_name):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]

    return "{}/{}".format(workspace_name, file.short_path)

def _tcl_lint_test_impl(ctx):
    srcs = [
        src
        for src in ctx.attr.target[TclInfo].srcs.to_list()
        if src.basename != "pkgIndex.tcl"
    ]

    config = ctx.file._config

    # Create an args file.
    args = ctx.actions.args()
    args.set_param_file_format("multiline")
    args.add("--config", _rlocationpath(config, ctx.workspace_name))
    args.add_all([
        "--src={}".format(_rlocationpath(src, ctx.workspace_name))
        for src in srcs
    ])

    args_file = ctx.actions.declare_file("{}.args.txt".format(ctx.label.name))
    ctx.actions.write(
        output = args_file,
        content = args,
    )

    # Create a symlink of `_linter`
    runner = ctx.executable._linter
    executable = ctx.actions.declare_file("{}.{}".format(ctx.label.name, runner.extension).rstrip("."))
    ctx.actions.symlink(
        output = executable,
        target_file = runner,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles(
                files = srcs + [config, args_file],
            ).merge(
                ctx.attr._linter[DefaultInfo].default_runfiles,
            ),
        ),
        RunEnvironmentInfo(
            environment = {
                "RULES_TCL_LINT_ARGS_FILE": _rlocationpath(args_file, ctx.workspace_name),
            },
        ),
    ]

tcl_lint_test = rule(
    doc = "A test for performing lint checks on a tcl target.",
    implementation = _tcl_lint_test_impl,
    test = True,
    attrs = {
        "target": attr.label(
            doc = "The target to perform linting on.",
            providers = [TclInfo],
            mandatory = True,
        ),
        "_config": attr.label(
            allow_single_file = True,
            default = Label("//tcl/settings:tclint_config"),
        ),
        "_linter": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//tcl/private/linting:linter"),
        ),
    },
)

def _tcl_format_test_impl(ctx):
    srcs = [
        src
        for src in ctx.attr.target[TclInfo].srcs.to_list()
        if src.basename != "pkgIndex.tcl"
    ]

    config = ctx.file._config

    # Create an args file.
    args = ctx.actions.args()
    args.set_param_file_format("multiline")
    args.add("--config", _rlocationpath(config, ctx.workspace_name))
    args.add_all([
        "--src={}".format(_rlocationpath(src, ctx.workspace_name))
        for src in srcs
    ])

    args_file = ctx.actions.declare_file("{}.args.txt".format(ctx.label.name))
    ctx.actions.write(
        output = args_file,
        content = args,
    )

    # Create a symlink of `_formatter`
    runner = ctx.executable._formatter
    executable = ctx.actions.declare_file("{}.{}".format(ctx.label.name, runner.extension).rstrip("."))
    ctx.actions.symlink(
        output = executable,
        target_file = runner,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles(
                files = srcs + [config, args_file],
            ).merge(
                ctx.attr._formatter[DefaultInfo].default_runfiles,
            ),
        ),
        RunEnvironmentInfo(
            environment = {
                "RULES_TCL_FORMAT_ARGS_FILE": _rlocationpath(args_file, ctx.workspace_name),
            },
        ),
    ]

tcl_format_test = rule(
    doc = "A test for performing format checks on a tcl target.",
    implementation = _tcl_format_test_impl,
    test = True,
    attrs = {
        "target": attr.label(
            doc = "The target to perform formatting checks on.",
            providers = [TclInfo],
            mandatory = True,
        ),
        "_config": attr.label(
            allow_single_file = True,
            default = Label("//tcl/settings:tclint_config"),
        ),
        "_formatter": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//tcl/private/linting:format_checker"),
        ),
    },
)
