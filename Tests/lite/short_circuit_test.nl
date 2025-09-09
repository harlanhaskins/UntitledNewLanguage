// RUN: %newlang %s -o %t && %t
// Comprehensive short-circuit test - returns 0 on success, test number on failure

// Test individual cases and return the test number if it fails

func main() -> Int32 {
    // Test 1: Basic && short-circuit
    if (false && true) == false {
        // PASS
    } else {
        return Int32(1)
    }
    
    // Test 2: Basic || short-circuit  
    if (true || false) == true {
        // PASS
    } else {
        return Int32(2)
    }
    
    // Test 3: && with evaluation
    if (true && false) == false {
        // PASS
    } else {
        return Int32(3)
    }
    
    // Test 4: || with evaluation
    if (false || true) == true {
        // PASS
    } else {
        return Int32(4)
    }
    
    // Test 5: All true case
    if (true && true) == true {
        // PASS
    } else {
        return Int32(5)
    }
    
    // Test 6: All false case
    if (false || false) == false {
        // PASS
    } else {
        return Int32(6)
    }
    
    // Test 7: Nested (false && true) || true
    if ((false && true) || true) == true {
        // PASS
    } else {
        return Int32(7)
    }
    
    // Test 8: Nested (true || false) && false
    if ((true || false) && false) == false {
        // PASS
    } else {
        return Int32(8)
    }
    
    // Test 9: Complex nested expression
    if (((false && true) || false) && true) == false {
        // PASS
    } else {
        return Int32(9)
    }
    
    // Test 10: Another complex case
    if (((true || false) && true) || false) == true {
        // PASS
    } else {
        return Int32(10)
    }
    
    // All tests passed!
    return Int32(0)
}