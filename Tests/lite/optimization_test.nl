// RUN: %newlang %s -O --emit-c 2>/dev/null | %FileCheck %s
// RUN: %newlang %s -O -o /dev/null --verbose 2>&1 | %FileCheck %s --check-prefixes CHECK-VERBOSE
// Test that -O flag enables optimizations

func simpleArithmetic(_ x: Int) -> Int {
    var temp = x + 0  // This could be optimized to just x
    temp = temp * 1   // This could be optimized to temp
    return temp + 5
}

func main() -> Int32 {
    var result = simpleArithmetic(10)
    return Int32(0)
}

// CHECK: int64_t simpleArithmetic(int64_t t) {
// CHECK:     return
// CHECK: }

// CHECK-VERBOSE: - Optimize: true
// CHECK-VERBOSE: Running optimization passes

// This test verifies that:
// 1. The -O flag emits valid C code without errors
// 2. The verbose output shows optimization passes are enabled
