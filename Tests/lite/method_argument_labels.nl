// RUN: %newlang %s --emit typecheck 2>/dev/null | %FileCheck %s --check-prefixes CHECK-TC

struct Adder {
    var base: Int

    func add(_ a: Int, b: Int, c: Int) -> Int {
        return base + a + b + c
    }
}

func main() -> Int32 {
    var ad = Adder(base: 10)
    var ok = ad.add(1, b: 2, c: 3)
    var bad1 = ad.add(a: 1, b: 2, c: 3)   // unexpected 'a:'
    var bad2 = ad.add(1, c: 3, b: 2)      // labels out of order
    var bad3 = ad.add(1, d: 2, c: 3)      // incorrect 'd:' expected 'b:'
    return Int32(0)
}

// CHECK-TC: Error: {{.*}} error [type-checker]: unexpected argument label 'a:'
// CHECK-TC: Error: {{.*}} error [type-checker]: argument labels out of order; expected [b, c] but got [c, b]
// CHECK-TC: Error: {{.*}} error [type-checker]: incorrect argument label 'd:' (expected 'b:')

