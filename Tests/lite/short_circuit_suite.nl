// RUN: %newlang %s -o %t && %t
// Comprehensive test suite for short-circuit operators
// Returns 0 if all tests pass, or the test number that failed

// Basic && tests
func test1() -> Bool {
    return (false && false) == false  // Should short-circuit to false
}

func test2() -> Bool {
    return (false && true) == false   // Should short-circuit to false
}

func test3() -> Bool {
    return (true && false) == false   // Should evaluate right and return false
}

func test4() -> Bool {
    return (true && true) == true     // Should evaluate right and return true
}

// Basic || tests
func test5() -> Bool {
    return (true || false) == true    // Should short-circuit to true
}

func test6() -> Bool {
    return (true || true) == true     // Should short-circuit to true
}

func test7() -> Bool {
    return (false || false) == false  // Should evaluate right and return false
}

func test8() -> Bool {
    return (false || true) == true    // Should evaluate right and return true
}

// Nested (X && Y) || Z tests
func test9() -> Bool {
    return ((false && true) || true) == true   // false || true = true
}

func test10() -> Bool {
    return ((false && false) || false) == false // false || false = false
}

func test11() -> Bool {
    return ((true && false) || true) == true    // false || true = true
}

func test12() -> Bool {
    return ((true && true) || false) == true    // true || false = true
}

// Nested X && (Y || Z) tests  
func test13() -> Bool {
    return (false && (true || false)) == false  // Should short-circuit
}

func test14() -> Bool {
    return (true && (false || true)) == true    // true && true = true
}

func test15() -> Bool {
    return (true && (false || false)) == false  // true && false = false
}

// Complex nested tests
func test16() -> Bool {
    return (((false && true) || false) && true) == false // (false || false) && true = false
}

func test17() -> Bool {
    return (((true || false) && true) || false) == true  // (true && true) || false = true
}

// Helper function to run all tests
func runTest(_ testNum: Int32) -> Bool {
    if testNum == Int32(1) { return test1() }
    if testNum == Int32(2) { return test2() }
    if testNum == Int32(3) { return test3() }
    if testNum == Int32(4) { return test4() }
    if testNum == Int32(5) { return test5() }
    if testNum == Int32(6) { return test6() }
    if testNum == Int32(7) { return test7() }
    if testNum == Int32(8) { return test8() }
    if testNum == Int32(9) { return test9() }
    if testNum == Int32(10) { return test10() }
    if testNum == Int32(11) { return test11() }
    if testNum == Int32(12) { return test12() }
    if testNum == Int32(13) { return test13() }
    if testNum == Int32(14) { return test14() }
    if testNum == Int32(15) { return test15() }
    if testNum == Int32(16) { return test16() }
    if testNum == Int32(17) { return test17() }
    return false
}

func main() -> Int32 {
    // Run tests 1 through 17
    var testNum = Int32(1)
    
    // Test 1-8: Basic cases
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    
    // Test 9-17: Nested cases  
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    if runTest(testNum) { testNum = testNum + Int32(1) } else { return testNum }
    
    // All 17 tests passed!
    return Int32(0)
}
