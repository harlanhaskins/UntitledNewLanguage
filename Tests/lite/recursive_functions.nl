// RUN: %newlang %s --emit c 2>/dev/null | %FileCheck %s --check-prefixes CHECK-C
// RUN: %newlang %s -o %t && %t | %FileCheck %s --check-prefixes CHECK-OUTPUT
// Test recursive functions with C stdlib integration

// C stdlib function declarations
@extern(c)
func printf(_ format: *Int8, ...)

@extern(c) 
func puts(_ str: *Int8) -> Int32

@extern(c)
func malloc(_ size: Int) -> *Int8

@extern(c)
func free(_ ptr: *Int8)

// Recursive factorial function
func factorial(_ n: Int) -> Int {
    if n <= 1 {
        return 1
    } else {
        return n * factorial(n - 1)
    }
}

// Recursive fibonacci function  
func fibonacci(_ n: Int) -> Int {
    if n <= 1 {
        return n
    } else {
        return fibonacci(n - 1) + fibonacci(n - 2)
    }
}

// Recursive power function
func power(_ base: Int, _ exp: Int) -> Int {
    if exp == 0 {
        return 1
    } else if exp == 1 {
        return base
    } else {
        return base * power(base, exp - 1)
    }
}

// Recursive greatest common divisor (Euclidean algorithm)
func gcd(_ a: Int, _ b: Int) -> Int {
    if b == 0 {
        return a
    } else {
        return gcd(b, a % b)
    }
}

// Recursive sum of array elements (simulated with count)
func sumToN(_ n: Int) -> Int {
    if n <= 0 {
        return 0
    } else {
        return n + sumToN(n - 1)
    }
}

func main() -> Int32 {
    // Test factorial: 5! = 120, 0! = 1
    printf("factorial(5) = %lld\n", factorial(5))
    printf("factorial(0) = %lld\n", factorial(0))
    
    // Test fibonacci: fib(7) = 13, fib(1) = 1
    printf("fibonacci(7) = %lld\n", fibonacci(7))
    printf("fibonacci(1) = %lld\n", fibonacci(1))
    
    // Test power: 2^3 = 8, 5^0 = 1
    printf("power(2, 3) = %lld\n", power(2, 3))
    printf("power(5, 0) = %lld\n", power(5, 0))
    
    // Test gcd: gcd(48, 18) = 6
    printf("gcd(48, 18) = %lld\n", gcd(48, 18))
    
    // Test sumToN: sum(1..10) = 55
    printf("sumToN(10) = %lld\n", sumToN(10))
    
    return Int32(0)
}

// CHECK-C: int64_t factorial(
// CHECK-C: {{t[0-9]+}} = {{t[0-9]+}} <= {{[0-9]+}};
// CHECK-C: if ({{t[0-9]+}}) goto then; else goto else_block;
// CHECK-C: then:
// CHECK-C: return {{[0-9]+}};
// CHECK-C: else_block:
// CHECK-C: {{t[0-9]+}} = {{t[0-9]+}} - {{[0-9]+}};
// CHECK-C: factorial(
// CHECK-C: // %{{[0-9]+}} = integer_mul %{{[0-9]+}} : $Int, %{{[0-9]+}} : $Int
// CHECK-C: return {{t[0-9]+}};
// CHECK-C: }

// CHECK-C: int64_t fibonacci(
// CHECK-C: {{t[0-9]+}} = {{t[0-9]+}} <= {{[0-9]+}};
// CHECK-C: if ({{t[0-9]+}}) goto then; else goto else_block;
// CHECK-C: then:
// CHECK-C: return {{t[0-9]+}};
// CHECK-C: else_block:
// CHECK-C: {{t[0-9]+}} = {{t[0-9]+}} - {{[0-9]+}};
// CHECK-C: fibonacci(
// CHECK-C: {{t[0-9]+}} = {{t[0-9]+}} - {{[0-9]+}};
// CHECK-C: fibonacci(
// CHECK-C: // %{{[0-9]+}} = integer_add %{{[0-9]+}} : $Int, %{{[0-9]+}} : $Int
// CHECK-C: return {{t[0-9]+}};
// CHECK-C: }

// CHECK-C: int64_t power(
// CHECK-C: // %{{[0-9]+}} = integer_mul %{{[0-9]+}} : $Int, %{{[0-9]+}} : $Int
// CHECK-C: return {{t[0-9]+}};
// CHECK-C: }

// CHECK-C: int64_t gcd(
// CHECK-C: {{t[0-9]+}} = {{t[0-9]+}} == {{[0-9]+}};
// CHECK-C: if ({{t[0-9]+}}) goto then; else goto else_block;
// CHECK-C: then:
// CHECK-C: return {{t[0-9]+}};
// CHECK-C: else_block:
// CHECK-C: // %{{[0-9]+}} = integer_mod %{{[0-9]+}} : $Int, %{{[0-9]+}} : $Int
// CHECK-C: gcd(
// CHECK-C: return {{t[0-9]+}};
// CHECK-C: }

// CHECK-C: int64_t sumToN(int64_t t) {
// CHECK-C: {{t[0-9]+}} = {{t[0-9]+}} <= {{[0-9]+}};
// CHECK-C: if ({{t[0-9]+}}) goto then; else goto else_block;
// CHECK-C:     return 0;
// CHECK-C: // %{{[0-9]+}} = apply @sumToN
// CHECK-C:     return t{{[0-9]+}};
// CHECK-C: }

// CHECK-OUTPUT: factorial(5) = 120
// CHECK-OUTPUT: factorial(0) = 1
// CHECK-OUTPUT: fibonacci(7) = 13
// CHECK-OUTPUT: fibonacci(1) = 1
// CHECK-OUTPUT: power(2, 3) = 8
// CHECK-OUTPUT: power(5, 0) = 1
// CHECK-OUTPUT: gcd(48, 18) = 6
// CHECK-OUTPUT: sumToN(10) = 55
