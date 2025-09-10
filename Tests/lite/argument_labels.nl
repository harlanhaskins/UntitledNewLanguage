// RUN: %newlang %s --emit typecheck 2>/dev/null | %FileCheck %s --check-prefixes CHECK-TC

func f(_ a: Int, b c: Int, d: Int) -> Int {
    return a + c + d
}

func main() -> Int32 {
    var ok = f(1, b: 2, d: 3)
    var bad1 = f(a: 1, b: 2, d: 3)      // unexpected 'a:'
    var bad2 = f(1, c: 2, d: 3)         // incorrect 'c:' expected 'b:'
    var bad3 = f(1, d: 3, b: 2)         // labels out of order
    return Int32(0)
}

// CHECK-TC: Error: {{.*}} error [type-checker]: unexpected argument label 'a:'
// CHECK-TC: Error: {{.*}} error [type-checker]: incorrect argument label 'c:' (expected 'b:')
// CHECK-TC: Error: {{.*}} error [type-checker]: argument labels out of order; expected [b, d] but got [d, b]
