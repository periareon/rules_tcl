# A test library for formatting checks.

namespace eval testlib {
    proc hello {name} {
        return "Hello, $name!"
    }

    proc add {a b} {
        return [expr {$a + $b}]
    }

    package provide testlib 1.0
}
