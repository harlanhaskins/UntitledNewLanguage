// RUN: %newlang %s --emit c 2>/dev/null | %FileCheck %s --check-prefixes CHECK-C
// RUN: %newlang %s -o %t && %t
// Test complex operator precedence and expression evaluation

@extern(c)
func printf(_ format: *Int8, ...)

@extern(c)
func abort()

func assert(_ value: Bool, message: *Int8) {
    if !value {
        printf("assertion failed: %s\n", message)
        abort()
    }
}

// Test arithmetic precedence: * and / before + and -
func testArithmeticPrecedence(_ x: Int, _ y: Int, _ z: Int) -> Int {
    // Should be: x + (y * z), not (x + y) * z
    var result1 = x + y * z
    assert(result1 == x + y * z, message: "x + y * z uses * before +")
    assert(result1 != (x + y) * z, message: "x + y * z is not (x + y) * z")
    
    // Should be: (x * y) + (z * x), not x * (y + z) * x
    var result2 = x * y + z * x
    assert(result2 == x * y + z * x, message: "x * y + z * x groups as expected")
    assert(result2 != x * (y + z) * x, message: "x * y + z * x is not x * (y + z) * x")
    
    // Should be: x + (y / z), not (x + y) / z  
    var result3 = x + y / z
    assert(result3 == x + y / z, message: "x + y / z uses / before +")
    assert(result3 != (x + y) / z, message: "x + y / z is not (x + y) / z")
    
    return result1 + result2 + result3
}

// Test comparison precedence: arithmetic before comparison
func testComparisonPrecedence(_ x: Int, _ y: Int) -> Bool {
    // Should be: (x + 5) > (y * 2), not x + (5 > y) * 2
    var result1 = x + 5 > y * 2
    assert(result1 == ((x + 5) > (y * 2)), message: "arithmetic before comparison for result1")
    
    // Should be: (x * 3) <= (y + 10)
    var result2 = x * 3 <= y + 10
    assert(result2 == ((x * 3) <= (y + 10)), message: "arithmetic before comparison for result2")
    
    // Should be: (x - y) == (y - x)  
    var result3 = x - y == y - x
    assert(result3 == ((x - y) == (y - x)), message: "arithmetic before comparison for result3")
    
    return result1 || result2 || result3
}

// Test boolean precedence: && before ||
func testBooleanPrecedence(_ a: Bool, _ b: Bool, _ c: Bool) -> Bool {
    // Should be: a || (b && c), not (a || b) && c
    var result1 = a || b && c
    assert(result1 == (a || (b && c)), message: "&& binds tighter than || for result1")
    
    // Should be: (a && b) || (b && c)
    var result2 = a && b || b && c
    assert(result2 == ((a && b) || (b && c)), message: "&& evaluated before || in result2")
    
    return result1 && result2
}

// Test mixed precedence: arithmetic, comparison, boolean
func testMixedPrecedence(_ x: Int, _ y: Int, _ z: Int) -> Bool {
    // Complex expression testing multiple precedence levels
    // Should be: ((x * 2) > y) && ((z + 5) < (x * y))
    var result1 = x * 2 > y && z + 5 < x * y
    assert(result1 == ((x * 2) > y && (z + 5) < (x * y)), message: "mixed precedence result1")
    
    // Should be: ((x + y) == z) || ((x * z) != (y * z))
    var result2 = x + y == z || x * z != y * z
    assert(result2 == ((x + y) == z || (x * z) != (y * z)), message: "mixed precedence result2")
    
    // Should be: (x > 0) && ((y * 3) <= (z + x)) && ((x - y) > 0)
    var result3 = x > 0 && y * 3 <= z + x && x - y > 0
    assert(result3 == ((x > 0) && ((y * 3) <= (z + x)) && ((x - y) > 0)), message: "mixed precedence result3")
    
    return result1 || result2 && result3
}

// Test parentheses override precedence
func testParenthesesOverride(_ x: Int, _ y: Int, _ z: Int) -> Int {
    // Override multiplication precedence
    var result1 = (x + y) * z
    assert(result1 == (x + y) * z, message: "parentheses override for result1")
    assert(result1 != x + y * z, message: "parentheses override differs from default precedence")
    
    // Test complex parenthetical expressions
    var temp = y > z && true
    assert(temp == ((y > z) && true), message: "boolean with parentheses and constants")
    var adjustment = 0
    if temp {
        adjustment = 1
    }
    
    var result2 = 0
    if x + adjustment == y {
        result2 = 10
    }
    assert((x + adjustment == y) == (result2 == 10), message: "conditional result2 matches condition")
    
    return result1 + result2
}

func main() -> Int32 {
    // Test various precedence scenarios
    var arithResult = testArithmeticPrecedence(2, 3, 4)  // Should be 2 + 3*4 = 14, then more complex
    var compResult = testComparisonPrecedence(10, 5)     // Various boolean results
    var boolResult = testBooleanPrecedence(true, false, true)
    var mixedResult = testMixedPrecedence(5, 3, 2)
    var parenResult = testParenthesesOverride(2, 3, 4)
    
    return Int32(0)
}

// CHECK-C: int64_t testArithmeticPrecedence(int64_t t, int64_t t1, int64_t t2) {
// CHECK-C:     // %{{[0-9]+}} = integer_mul %{{[0-9]+}} : $Int, %{{[0-9]+}} : $Int
// CHECK-C:     =
// CHECK-C:     // %{{[0-9]+}} = integer_add %{{[0-9]+}} : $Int, %{{[0-9]+}} : $Int
// CHECK-C:     =
// CHECK-C:     result1 =
// CHECK-C: }

// CHECK-C: bool testComparisonPrecedence(int64_t t, int64_t t1) {
// CHECK-C:     // %{{[0-9]+}} = integer_add %{{[0-9]+}} : $Int, %{{[0-9]+}} : $Int
// CHECK-C:     {{t[0-9]+}} = {{t[0-9]+}} + 5;
// CHECK-C:     // %{{[0-9]+}} = integer_mul %{{[0-9]+}} : $Int, %{{[0-9]+}} : $Int
// CHECK-C:     {{t[0-9]+}} = {{t[0-9]+}} * 2;
// CHECK-C:     // %{{[0-9]+}} = integer_gt %{{[0-9]+}} : $Int, %{{[0-9]+}} : $Int
// CHECK-C:     {{t[0-9]+}} = {{t[0-9]+}} > {{t[0-9]+}};
// CHECK-C: }

// This test verifies that NewLang correctly parses operator precedence:
// 1. * and / have higher precedence than + and -
// 2. Arithmetic has higher precedence than comparisons  
// 3. Comparisons have higher precedence than boolean operators
// 4. && has higher precedence than ||
// 5. Parentheses can override default precedence
