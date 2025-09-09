// RUN: %newlang %s --emit parse 2>/dev/null | %FileCheck %s --check-prefixes CHECK-PARSE
// RUN: %newlang %s --emit typecheck 2>/dev/null | %FileCheck %s --check-prefixes CHECK-TC

struct Point {
    var x: Int
    var y: Int

    func sum() -> Int {
        return x + y
    }

    func add(_ dx: Int, _ dy: Int) -> Int {
        return (x + dx) + (y + dy)
    }
}

func main() -> Int32 { return Int32(0) }

// CHECK-PARSE: (struct Point
// CHECK-PARSE:   (field x)
// CHECK-PARSE:   (field y)
// CHECK-PARSE:   (func sum (params)
// CHECK-PARSE:   (func add (params (dx) (dy))

// CHECK-TC: (struct Point
// CHECK-TC:   (field x: Int)
// CHECK-TC:   (field y: Int)
// CHECK-TC:   (func sum (params) (return Int)
// CHECK-TC:     (block
// CHECK-TC:       (return (bin (id x: Int) add (id y: Int): Int))
// CHECK-TC:   (func add (params (dx: Int) (dy: Int)) (return Int)
// CHECK-TC:     (block
// CHECK-TC:       (return (bin (bin (id x: Int) add (id dx: Int): Int) add (bin (id y: Int) add (id dy: Int): Int): Int))
