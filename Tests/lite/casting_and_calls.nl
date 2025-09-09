// RUN: %newlang %s -o %t && %t | %FileCheck %s --check-prefixes CHECK-OUTPUT
// Casting with unary minus and comparisons in a simple pipeline

@extern(c)
func printf(_ format: *Int8, ...)

func boolStr(_ b: Bool) -> *Int8 {
    if b {
        return "true"
    } else {
        return "false"
    }
}

func twice(_ x: Int) -> Int { return x + x }
func negate(_ x: Int) -> Int { return -x }

func main() -> Int32 {
    var x = twice(5)         // 10
    var y = negate(x)        // -10
    var z = -y               // 10

    printf("x=%lld y=%lld z=%lld\n", x, y, z)

    // Cast to narrower type and print
    var xi32 = Int32(x)
    var yi32 = Int32(y)
    printf("xi32=%d yi32=%d\n", xi32, yi32)

    // Mixed comparisons
    var ok = (x == z) && (y < 0) && !(x < 0)
    printf("ok=%s\n", boolStr(ok))

    return Int32(0)
}

// CHECK-OUTPUT: x=10 y=-10 z=10
// CHECK-OUTPUT: xi32=10 yi32=-10
// CHECK-OUTPUT: ok=true
