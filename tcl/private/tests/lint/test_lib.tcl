# A test library for linting checks.

namespace eval testlib {
    proc hello {name} {
        return "Hello, $name!"
    }

    proc add {a b} {
        return [expr {$a + $b}]
    }

    package provide testlib 1.0
}
