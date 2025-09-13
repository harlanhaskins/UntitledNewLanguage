// RUN: %newlang %s --emit nir 2>/dev/null | %FileCheck %s --check-prefixes CHECK-NIR

struct Counter {
    var value: Int
    func inc(_ d: Int) { value = value + d }
}

func demo() {
    var c: Counter
    c.value = 1
    c.inc(2)
}

// CHECK-NIR: nir @Counter_inc
// CHECK-NIR: nir @demo
// CHECK-NIR: apply @Counter_inc(
