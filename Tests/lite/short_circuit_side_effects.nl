// RUN: %newlang %s -o %t && %t | %FileCheck %s --check-prefixes CHECK-OUTPUT
// Ensure short-circuiting prevents side-effect calls on the non-taken side

@extern(c)
func puts(_ str: *Int8) -> Int32

func printAndTrue(_ msg: *Int8) -> Bool {
    puts(msg)
    return true
}

func printAndFalse(_ msg: *Int8) -> Bool {
    puts(msg)
    return false
}

func main() -> Int32 {
    // true || X should not evaluate X
    var a = true || printAndTrue("OR-right-true-should-not-print")

    // false && X should not evaluate X
    var b = false && printAndFalse("AND-right-false-should-not-print")

    // Evaluate right for true && X
    var c = true && printAndTrue("AND-right-true-printed")

    // Evaluate right for false || X
    var d = false || printAndFalse("OR-right-false-printed")

    // Use results to avoid unused warnings
    if a && !b && c && !d { puts("OK") }

    return Int32(0)
}

// CHECK-OUTPUT: AND-right-true-printed
// CHECK-OUTPUT: OR-right-false-printed
// CHECK-OUTPUT: OK

