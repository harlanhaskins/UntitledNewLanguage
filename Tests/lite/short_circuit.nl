// RUN: %newlang %s -o %t && %t
// Test short-circuiting behavior of && and || operators
// Tests the logical correctness of short-circuit evaluation

// Test && short-circuiting: false && X should always be false
func testAndShortCircuit() -> Bool {
    // Test that false && true = false
    var result1 = false && true
    if result1 != false {
        return false
    }
    
    // Test that false && false = false  
    var result2 = false && false
    if result2 != false {
        return false
    }
    
    // Test that true && true = true
    var result3 = true && true
    if result3 != true {
        return false
    }
    
    // Test that true && false = false
    var result4 = true && false
    if result4 != false {
        return false
    }
    
    return true
}

// Test || short-circuiting: true || X should always be true
func testOrShortCircuit() -> Bool {
    // Test that true || false = true
    var result1 = true || false
    if result1 != true {
        return false
    }
    
    // Test that true || true = true
    var result2 = true || true
    if result2 != true {
        return false
    }
    
    // Test that false || true = true
    var result3 = false || true
    if result3 != true {
        return false
    }
    
    // Test that false || false = false
    var result4 = false || false
    if result4 != false {
        return false
    }
    
    return true
}

// Test complex boolean expressions
func testComplexExpressions() -> Bool {
    // Test that (false && true) || true = true
    var result1 = (false && true) || true
    if result1 != true {
        return false
    }
    
    // Test that false && (true || false) = false
    var result2 = false && (true || false)
    if result2 != false {
        return false
    }
    
    // Test that true || (false && true) = true
    var result3 = true || (false && true)
    if result3 != true {
        return false
    }
    
    // Test that (true || false) && (false || true) = true
    var result4 = (true || false) && (false || true)
    if result4 != true {
        return false
    }
    
    return true
}

// Test with variables to ensure proper evaluation
func testWithVariables() -> Bool {
    var x = true
    var y = false
    
    // Test x && y = false
    var result1 = x && y
    if result1 != false {
        return false
    }
    
    // Test x || y = true  
    var result2 = x || y
    if result2 != true {
        return false
    }
    
    // Test y && x = false
    var result3 = y && x
    if result3 != false {
        return false
    }
    
    // Test y || x = true
    var result4 = y || x
    if result4 != true {
        return false
    }
    
    return true
}

func main() -> Int32 {
    var passed = 0
    var total = 4
    
    // Test && short-circuiting logic
    if testAndShortCircuit() {
        passed = passed + 1
    }
    
    // Test || short-circuiting logic
    if testOrShortCircuit() {
        passed = passed + 1
    }
    
    // Test complex expressions
    if testComplexExpressions() {
        passed = passed + 1
    }
    
    // Test with variables
    if testWithVariables() {
        passed = passed + 1
    }
    
    // Return number of failed tests (0 = all passed)
    return Int32(total - passed)
}