// RUN: %newlang %s -o %t && %t
// Final comprehensive test for short-circuit operators
// Each test is in its own function to avoid control flow conflicts

// Basic tests
func testBasicAndShortCircuit() -> Bool {
    return (false && true) == false
}

func testBasicOrShortCircuit() -> Bool {
    return (true || false) == true
}

func testAndWithEvaluation() -> Bool {
    return (true && false) == false
}

func testOrWithEvaluation() -> Bool {
    return (false || true) == true
}

func testAllTrue() -> Bool {
    return (true && true) == true
}

func testAllFalse() -> Bool {
    return (false || false) == false
}

// Nested tests
func testNestedAndOr1() -> Bool {
    return ((false && true) || true) == true
}

func testNestedAndOr2() -> Bool {
    return ((true && false) || false) == false
}

func testNestedOrAnd1() -> Bool {
    return ((true || false) && false) == false
}

func testNestedOrAnd2() -> Bool {
    return ((false || true) && true) == true
}

// Complex nested tests
func testComplexNested1() -> Bool {
    return (((false && true) || false) && true) == false
}

func testComplexNested2() -> Bool {
    return (((true || false) && true) || false) == true
}

func testComplexNested3() -> Bool {
    return ((false || (true && false)) && true) == false
}

// Test runner that checks each function
func main() -> Int32 {
    if testBasicAndShortCircuit() {
        if testBasicOrShortCircuit() {
            if testAndWithEvaluation() {
                if testOrWithEvaluation() {
                    if testAllTrue() {
                        if testAllFalse() {
                            if testNestedAndOr1() {
                                if testNestedAndOr2() {
                                    if testNestedOrAnd1() {
                                        if testNestedOrAnd2() {
                                            if testComplexNested1() {
                                                if testComplexNested2() {
                                                    if testComplexNested3() {
                                                        return Int32(0)  // All tests passed!
                                                    } else { return Int32(13) }
                                                } else { return Int32(12) }
                                            } else { return Int32(11) }
                                        } else { return Int32(10) }
                                    } else { return Int32(9) }
                                } else { return Int32(8) }
                            } else { return Int32(7) }
                        } else { return Int32(6) }
                    } else { return Int32(5) }
                } else { return Int32(4) }
            } else { return Int32(3) }
        } else { return Int32(2) }
    } else { return Int32(1) }
}