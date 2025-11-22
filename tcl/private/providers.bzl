"""TCL Providers"""

TclInfo = provider(
    doc = "Info about a Tcl target.",
    fields = {
        "includes": "Depset[str]: A list of include paths associated with the current target.",
        "srcs": "Depset[File]: Direct source files of the current target.",
        "transitive_includes": "Depset[str]: Include paths from dependencies.",
        "transitive_srcs": "Depset[File]: Source files required at runtime from dependencies.",
    },
)
