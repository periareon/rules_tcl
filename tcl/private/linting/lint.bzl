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
    doc = """\
An aspect for performing linting checks on Tcl targets.

The `tcl_lint_aspect` applies linting checks to all Tcl targets in the dependency graph.
It uses [tclint](https://github.com/nmoroze/tclint) to check for code quality issues.

**Usage:**

Apply the aspect to check all dependencies of a target via command line:

```bash
bazel build //my:target --aspects=@rules_tcl//tcl:tcl_lint_aspect.bzl%tcl_lint_aspect
```

Or configure it in your `.bazelrc` file to enable linting for all builds:

```bazelrc
# Enable tclint for all targets in the workspace
build:tclint --aspects=@rules_tcl//tcl:tcl_lint_aspect.bzl%tcl_lint_aspect
build:tclint --output_groups=+tcl_lint_checks
```

Then use it with:
```bash
bazel build //my:target --config=tclint
```

Or use it in a test:

```python
load("@rules_tcl//tcl:tcl_lint_test.bzl", "tcl_lint_test")

tcl_lint_test(
    name = "lint_check",
    target = ":my_library",
)
```

**Ignoring targets:**

To skip linting for specific targets, add one of these tags:
- `no_tcl_lint`
- `no_lint`
- `nolint`

```python
tcl_library(
    name = "legacy_code",
    srcs = ["legacy.tcl"],
    tags = ["no_tcl_lint"],
)
```

The aspect only processes source files (not generated files) and excludes `pkgIndex.tcl` files.
""",
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
    doc = """\
An aspect for performing formatting checks on Tcl targets.

The `tcl_format_aspect` checks that Tcl source files are properly formatted according to
the configured style. It uses [tclint](https://github.com/nmoroze/tclint) to verify formatting.

**Usage:**

Apply the aspect to check formatting of all dependencies via command line:

```bash
bazel build //my:target --aspects=@rules_tcl//tcl:tcl_format_aspect.bzl%tcl_format_aspect
```

Or configure it in your `.bazelrc` file to enable format checking for all builds:

```bazelrc
# Enable tclfmt for all targets in the workspace
build:tclfmt --aspects=@rules_tcl//tcl:tcl_format_aspect.bzl%tcl_format_aspect
build:tclfmt --output_groups=+tcl_format_checks
```

Then use it with:
```bash
bazel build //my:target --config=tclfmt
```

Or use it in a test:

```python
load("@rules_tcl//tcl:tcl_format_test.bzl", "tcl_format_test")

tcl_format_test(
    name = "format_check",
    target = ":my_library",
)
```

**Ignoring targets:**

To skip format checking for specific targets, add one of these tags:
- `no_tcl_format`
- `no_tclformat`
- `no_tclfmt`
- `noformat`
- `nofmt`

```python
tcl_library(
    name = "generated_code",
    srcs = ["generated.tcl"],
    tags = ["no_tcl_format"],
)
```

The aspect processes all source files including `pkgIndex.tcl` files.
""",
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
    doc = """\
A test rule for performing linting checks on a Tcl target.

The `tcl_lint_test` rule creates a test that verifies a Tcl target passes linting checks.
This is useful for enforcing code quality in CI/CD pipelines.

**Usage:**

```python
load("@rules_tcl//tcl:tcl_lint_test.bzl", "tcl_lint_test")

tcl_library(
    name = "mylib",
    srcs = ["mylib.tcl", "pkgIndex.tcl"],
)

tcl_lint_test(
    name = "mylib_lint",
    target = ":mylib",
)
```

Run the lint test with:

```bash
bazel test //path/to:mylib_lint
```

The test will fail if the target has any linting errors. The test automatically excludes
`pkgIndex.tcl` files from linting, as these are typically generated or follow a specific format.
""",
    implementation = _tcl_lint_test_impl,
    test = True,
    attrs = {
        "target": attr.label(
            doc = """\
The Tcl target to perform linting on.

This must be a target that provides `TclInfo` (e.g., `tcl_library`, `tcl_binary`, or `tcl_test`).
The test will lint all source files in this target, excluding `pkgIndex.tcl` files.
""",
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
    doc = """\
A test rule for performing formatting checks on a Tcl target.

The `tcl_format_test` rule creates a test that verifies a Tcl target's source files are
properly formatted according to the configured style. This is useful for enforcing
consistent code style in CI/CD pipelines.

**Usage:**

```python
load("@rules_tcl//tcl:tcl_format_test.bzl", "tcl_format_test")

tcl_library(
    name = "mylib",
    srcs = ["mylib.tcl", "pkgIndex.tcl"],
)

tcl_format_test(
    name = "mylib_format",
    target = ":mylib",
)
```

Run the format test with:

```bash
bazel test //path/to:mylib_format
```

The test will fail if any source files are not properly formatted. Unlike `tcl_lint_test`,
this test includes `pkgIndex.tcl` files in the formatting check.
""",
    implementation = _tcl_format_test_impl,
    test = True,
    attrs = {
        "target": attr.label(
            doc = """\
The Tcl target to perform formatting checks on.

This must be a target that provides `TclInfo` (e.g., `tcl_library`, `tcl_binary`, or `tcl_test`).
The test will check formatting for all source files in this target, including `pkgIndex.tcl` files.
""",
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
