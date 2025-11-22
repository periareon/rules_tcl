"""Tcl Bazel rules"""

load(":tcl_binary.bzl", _tcl_binary = "tcl_binary")
load(":tcl_format_aspect.bzl", _tcl_format_aspect = "tcl_format_aspect")
load(":tcl_format_test.bzl", _tcl_format_test = "tcl_format_test")
load(":tcl_library.bzl", _tcl_library = "tcl_library")
load(":tcl_lint_aspect.bzl", _tcl_lint_aspect = "tcl_lint_aspect")
load(":tcl_lint_test.bzl", _tcl_lint_test = "tcl_lint_test")
load(":tcl_toolchain.bzl", _tcl_toolchain = "tcl_toolchain")

tcl_binary = _tcl_binary
tcl_library = _tcl_library
tcl_toolchain = _tcl_toolchain
tcl_lint_aspect = _tcl_lint_aspect
tcl_lint_test = _tcl_lint_test
tcl_format_aspect = _tcl_format_aspect
tcl_format_test = _tcl_format_test
