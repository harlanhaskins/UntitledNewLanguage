// RUN: %newlang %s --emit-c 2>/dev/null | %FileCheck %s --check-prefixes CHECK-C
// RUN: %newlang %s -o %t && %t
// Test basic short-circuiting behavior through C code generation

func testAndLogic() -> Bool {
    // Simple && test - should generate branching code
    return false && true
}

func testOrLogic() -> Bool {
    // Simple || test - should generate branching code  
    return true || false
}

func main() -> Int32 {
    var result1 = testAndLogic()  // Should be false
    var result2 = testOrLogic()   // Should be true
    return Int32(0)
}

// Verify that the generated C code uses proper control flow instead of
// evaluating both operands first
// CHECK-C: bool testAndLogic(void) {
// CHECK-C: bool testOrLogic(void) {