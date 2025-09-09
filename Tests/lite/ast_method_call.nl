// RUN: %newlang %s --emit typecheck 2>/dev/null | %FileCheck %s --check-prefixes CHECK-TC

struct Point {
    var x: Int
    var y: Int
    func sum() -> Int { return x + y }
}

func demo(_ p: Point) -> Int {
    return p.sum()
}

func main() -> Int32 { return Int32(0) }

// CHECK-TC: (struct Point
// CHECK-TC:   (field x: Int)
// CHECK-TC:   (field y: Int)
// CHECK-TC:   (func sum (params) (return Int)

// CHECK-TC: (func demo (params (p: Point)) (return Int)
// CHECK-TC:   (block
// CHECK-TC:     (return (call (member (id p: Point).sum: () -> Int) []: Int))
