// Demonstrates working short-circuit cases
// This test should compile and run successfully

// Test 1: Basic nested expression returns correct result
func test1() -> Bool {
    return (false && true) || true  // Should be true
}

// Test 2: Different nested expression 
func test2() -> Bool {
    return (true && false) || false  // Should be false
}

// Test 3: Simple && case
func test3() -> Bool {
    return false && true  // Should be false
}

// Test 4: Simple || case  
func test4() -> Bool {
    return true || false  // Should be true
}

func main() -> Int32 {
    // Just call the functions to make sure they work
    // We can't easily test the return values without if statements
    // but we can verify they compile and execute
    
    test1()
    test2() 
    test3()
    test4()
    
    return Int32(0)  // Success - all functions executed without crashes
}