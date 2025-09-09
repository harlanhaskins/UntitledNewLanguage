// RUN: %newlang %s -o %t && %t
// Comprehensive test for short-circuit operators (&& and ||)
// Tests all combinations and nested expressions
// Returns 0 if all tests pass, non-zero if any test fails

// Test basic && operations
func testBasicAnd() -> Bool {
    // false && X should always be false (short-circuit)
    if (false && false) == false &&
       (false && true) == false {
        return true
    }
    return false
}

// Test basic || operations  
func testBasicOr() -> Bool {
    // true || X should always be true (short-circuit)
    if (true || false) == true &&
       (true || true) == true {
        return true
    }
    return false
}

// Test && with true on left (should evaluate right)
func testAndEvaluateRight() -> Bool {
    if (true && false) == false &&
       (true && true) == true {
        return true
    }
    return false
}

// Test || with false on left (should evaluate right)
func testOrEvaluateRight() -> Bool {
    if (false || false) == false &&
       (false || true) == true {
        return true
    }
    return false
}

// Test nested expressions: (X && Y) || Z
func testNestedAndOr() -> Bool {
    if ((false && true) || true) == true &&
       ((false && false) || false) == false &&
       ((true && false) || true) == true &&
       ((true && true) || false) == true {
        return true
    }
    return false
}

// Test nested expressions: X && (Y || Z)  
func testNestedAndOr2() -> Bool {
    if (false && (true || false)) == false &&
       (true && (false || true)) == true &&
       (true && (false || false)) == false &&
       (false && (true || true)) == false {
        return true
    }
    return false
}

// Test nested expressions: (X || Y) && Z
func testNestedOrAnd() -> Bool {
    if ((false || true) && true) == true &&
       ((false || false) && true) == false &&
       ((true || false) && false) == false &&
       ((true || true) && true) == true {
        return true
    }
    return false
}

// Test complex nested expressions
func testComplexNested() -> Bool {
    // ((false && true) || false) && true should be false
    if (((false && true) || false) && true) == false &&
       (((true || false) && true) || false) == true &&
       ((false || (true && false)) && true) == false {
        return true
    }
    return false
}

func main() -> Int32 {
    var passed = 0
    var total = 8
    
    if testBasicAnd() {
        passed = passed + 1
    }
    
    if testBasicOr() {
        passed = passed + 1  
    }
    
    if testAndEvaluateRight() {
        passed = passed + 1
    }
    
    if testOrEvaluateRight() {
        passed = passed + 1
    }
    
    if testNestedAndOr() {
        passed = passed + 1
    }
    
    if testNestedAndOr2() {
        passed = passed + 1
    }
    
    if testNestedOrAnd() {
        passed = passed + 1
    }
    
    if testComplexNested() {
        passed = passed + 1
    }
    
    // Return number of failed tests (0 = all passed)
    return Int32(total - passed)
}