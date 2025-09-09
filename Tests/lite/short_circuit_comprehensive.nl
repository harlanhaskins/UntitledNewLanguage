// RUN: %newlang %s -o %t && %t
// Comprehensive test for short-circuit operators (&& and ||)
// Uses only direct returns to avoid variable assignment issues
// Returns 0 if all tests pass, non-zero if any test fails

// Test 1: Basic && short-circuiting - false && X should be false
func test1() -> Bool {
    return (false && false) == false
}

func test2() -> Bool {
    return (false && true) == false
}

// Test 3: Basic || short-circuiting - true || X should be true  
func test3() -> Bool {
    return (true || false) == true
}

func test4() -> Bool {
    return (true || true) == true
}

// Test 5: && with true left - should evaluate right operand
func test5() -> Bool {
    return (true && false) == false
}

func test6() -> Bool {
    return (true && true) == true
}

// Test 7: || with false left - should evaluate right operand
func test7() -> Bool {
    return (false || false) == false
}

func test8() -> Bool {
    return (false || true) == true
}

// Test 9-12: Nested expressions (X && Y) || Z
func test9() -> Bool {
    return ((false && true) || true) == true
}

func test10() -> Bool {
    return ((false && false) || false) == false
}

func test11() -> Bool {
    return ((true && false) || true) == true
}

func test12() -> Bool {
    return ((true && true) || false) == true
}

// Test 13-16: Nested expressions X && (Y || Z)
func test13() -> Bool {
    return (false && (true || false)) == false
}

func test14() -> Bool {
    return (true && (false || true)) == true
}

func test15() -> Bool {
    return (true && (false || false)) == false
}

func test16() -> Bool {
    return (false && (true || true)) == false
}

// Test 17-20: Nested expressions (X || Y) && Z
func test17() -> Bool {
    return ((false || true) && true) == true
}

func test18() -> Bool {
    return ((false || false) && true) == false
}

func test19() -> Bool {
    return ((true || false) && false) == false
}

func test20() -> Bool {
    return ((true || true) && true) == true
}

// Test 21-23: Complex nested expressions
func test21() -> Bool {
    // ((false && true) || false) && true should be false
    return (((false && true) || false) && true) == false
}

func test22() -> Bool {
    // ((true || false) && true) || false should be true
    return (((true || false) && true) || false) == true
}

func test23() -> Bool {
    // (false || (true && false)) && true should be false
    return ((false || (true && false)) && true) == false
}

func main() -> Int32 {
    // Count passing tests - each test should return true
    
    // Basic tests
    if test1() == false { return Int32(1) }
    if test2() == false { return Int32(2) }
    if test3() == false { return Int32(3) }
    if test4() == false { return Int32(4) }
    if test5() == false { return Int32(5) }
    if test6() == false { return Int32(6) }
    if test7() == false { return Int32(7) }
    if test8() == false { return Int32(8) }

    // Nested tests
    if test9() == false { return Int32(9) }
    if test10() == false { return Int32(10) }
    if test11() == false { return Int32(11) }
    if test12() == false { return Int32(12) }
    if test13() == false { return Int32(13) }
    if test14() == false { return Int32(14) }
    if test15() == false { return Int32(15) }
    if test16() == false { return Int32(16) }
    if test17() == false { return Int32(17) }
    if test18() == false { return Int32(18) }
    if test19() == false { return Int32(19) }
    if test20() == false { return Int32(20) }

    // Complex tests
    if test21() == false { return Int32(21) }
    if test22() == false { return Int32(22) }
    if test23() == false { return Int32(23) }

    // All tests passed!
    return Int32(0)
}
