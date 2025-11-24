# A small test script

package require tcltest
namespace import ::tcltest::*

test addition-1-1 {test that 1+1 = 2} {
    expr {1 + 1}
} 2

cleanupTests
