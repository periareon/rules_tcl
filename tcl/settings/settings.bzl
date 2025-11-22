"""# TCL settings

Definitions for all `@rules_tcl//tcl` settings
"""

# buildifier: disable=unnamed-macro
def tclint_config():
    """The [tclint](https://github.com/nmoroze/tclint/blob/main/docs/configuration.md) config file to use in linting/formatting rules.
    """
    native.label_flag(
        name = "tclint_config",
        build_setting_default = ".tclint.toml",
    )
