# rules_tcl

Bazel rules for building, testing, and managing [Tcl](https://www.tcl-lang.org/) applications and libraries.

## Overview

`rules_tcl` provides a comprehensive set of Bazel rules for working with the Tcl scripting language. It supports:

- **Building executables** with `tcl_binary`
- **Creating reusable libraries** with `tcl_library`
- **Writing and running tests** with `tcl_test`
- **Code quality checks** with linting and formatting aspects
- **Dependency management** through Tcl's package system

The rules handle Tcl's package system, runfiles, and provide seamless integration with Bazel's build system.

## Quick Start

### Setup

Add the following to your `MODULE.bazel` file:

```python
bazel_dep(name = "rules_tcl", version = "{version}")

register_toolchains(
    "@rules_tcl//tcl/toolchain",
)
```

### Basic Example

Create a simple Tcl executable:

```python
load("@rules_tcl//tcl:tcl_binary.bzl", "tcl_binary")

tcl_binary(
    name = "hello",
    srcs = ["hello.tcl"],
)
```

### Library Example

Create a reusable Tcl library:

```python
load("@rules_tcl//tcl:tcl_library.bzl", "tcl_library")

tcl_library(
    name = "greetings",
    srcs = [
        "greet.tcl",
        "pkgIndex.tcl",  # Required for libraries
    ],
)
```

## Documentation

- [Rules Reference](./rules.md) - Complete documentation for all available rules
- [Examples](../examples/) - Working examples in the repository

## Features

- **Package System Support**: Automatic handling of `pkgIndex.tcl` files for Tcl's package system
- **Dependency Management**: Transitive dependency resolution for Tcl libraries
- **Code Quality**: Built-in linting and formatting checks using [tclint](https://github.com/nmoroze/tclint)
- **Test Support**: Native test rule with environment variable support
- **Cross-Platform**: Works on Linux, macOS, and Windows
- **Runfiles Integration**: Proper handling of data files and dependencies at runtime
