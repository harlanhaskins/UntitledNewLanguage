// RUN: %newlang %s --emit ssa 2>/dev/null | %FileCheck %s --check-prefixes CHECK-SSA

struct Counter {
    var value: Int
    func inc(_ d: Int) { value = value + d }
}

func demo() {
    var c: Counter
    c.value = 1
    c.inc(2)
}

// CHECK-SSA: ssa @Counter_inc
// CHECK-SSA: ssa @demo
// CHECK-SSA: apply @Counter_inc(
