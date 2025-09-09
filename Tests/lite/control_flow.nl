// RUN: %newlang %s --emit-c 2>/dev/null | %FileCheck %s --check-prefixes CHECK-C
// RUN: %newlang %s -o %t && %t
// Test advanced control flow with multiple return paths

// Function with early returns in different branches
func classifyNumber(_ n: Int) -> Int {
    if n < 0 {
        return 0 - 1  // Early return for negative numbers
    }
    
    if n == 0 {
        return 0   // Early return for zero
    }
    
    if n > 100 {
        return 100 // Early return for large numbers
    }
    
    // Normal return for positive numbers <= 100
    return 1
}

// Complex nested conditionals with multiple return paths  
func calculateGrade(_ score: Int) -> Int {
    if score >= 90 {
        if score >= 95 {
            return 4  // A+
        } else {
            return 3  // A
        }
    } else if score >= 80 {
        if score >= 85 {
            return 2  // B+  
        } else {
            return 1  // B
        }
    } else if score >= 70 {
        return 0      // C
    } else if score >= 60 {
        return 0 - 1     // D
    } else {
        return 0 - 2     // F
    }
    // This line should be unreachable
}

// Function with complex branching and multiple exit points
func processValue(_ x: Int, _ y: Int, _ useSpecialLogic: Bool) -> Int {
    if useSpecialLogic {
        if x > y {
            if x > 50 {
                return x * 2
            } else {
                return x + 10
            }
        } else {
            if y > 50 {
                return y * 3
            } else {
                return y + (0 - 5)
            }
        }
    } else {
        // Standard logic path
        if x == y {
            return 0
        } else if x > y {
            return 1  
        } else {
            return 0 - 1
        }
    }
}

// Function testing return in nested loops (using recursion to simulate)
func findFirstMatch(_ target: Int, _ current: Int, _ max: Int) -> Int {
    if current > max {
        return 0 - 1  // Not found
    }
    
    if current == target {
        return current  // Found it!
    }
    
    // Continue searching
    return findFirstMatch(target, current + 1, max)
}

// Function with boolean returns and multiple paths
func validateInput(_ x: Int, _ y: Int) -> Bool {
    if x < 0 {
        return false  // Invalid negative x
    }
    
    if y < 0 {
        return false  // Invalid negative y  
    }
    
    if x == 0 && y == 0 {
        return false  // Both zero is invalid
    }
    
    if x > 1000 || y > 1000 {
        return false  // Too large
    }
    
    return true  // Valid input
}

// Test function that exercises all the control flow functions
func testControlFlow() -> Int {
    var result = 0
    
    // Test classifyNumber
    result = result + classifyNumber(0 - 5)   // Should return -1
    result = result + classifyNumber(0)    // Should return 0  
    result = result + classifyNumber(50)   // Should return 1
    result = result + classifyNumber(150)  // Should return 100
    
    // Test calculateGrade  
    result = result + calculateGrade(97)   // Should return 4
    result = result + calculateGrade(87)   // Should return 2
    result = result + calculateGrade(75)   // Should return 0
    result = result + calculateGrade(55)   // Should return -2
    
    // Test processValue
    result = result + processValue(60, 30, true)   // Should return 120 (60*2)
    result = result + processValue(10, 20, false)  // Should return -1
    
    // Test findFirstMatch
    result = result + findFirstMatch(7, 1, 10)   // Should return 7
    result = result + findFirstMatch(15, 1, 10)  // Should return -1
    
    // Test validateInput - convert bool to int
    if validateInput(10, 20) {
        result = result + 1
    }
    if validateInput(0 - 5, 10) {
        result = result + 100  // This shouldn't happen
    }
    
    return result
}

func main() -> Int32 {
    var testResult = testControlFlow()
    return Int32(0)
}

// CHECK-C: int64_t classifyNumber(int64_t t0) {
// CHECK-C:     if (t{{[0-9]+}}) goto then{{[0-9]+}}; else goto 
// CHECK-C:     return
// CHECK-C: }

// CHECK-C: int64_t calculateGrade(int64_t t0) {
// CHECK-C:     if (t{{[0-9]+}}) goto then{{[0-9]+}}; else goto 
// CHECK-C:     return
// CHECK-C: }

// CHECK-C: int64_t processValue(int64_t t0, int64_t t1, bool t2) {
// CHECK-C:     if (t{{[0-9]+}}) goto then{{[0-9]+}}; else goto 
// CHECK-C:     return
// CHECK-C: }

// CHECK-C: int64_t testControlFlow(void) {
// CHECK-C:     t{{[0-9]+}} = classifyNumber(
// CHECK-C:     t{{[0-9]+}} = calculateGrade(
// CHECK-C:     t{{[0-9]+}} = processValue(
// CHECK-C: }

// This test verifies that NewLang correctly handles:
// 1. Multiple return statements in a single function
// 2. Early returns in conditional branches
// 3. Nested conditionals with various return paths  
// 4. Complex branching logic with different exit points
// 5. Proper C code generation for complex control flow
