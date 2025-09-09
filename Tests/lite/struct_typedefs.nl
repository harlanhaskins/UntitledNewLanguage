// RUN: %newlang %s --emit c 2>/dev/null | %FileCheck %s --check-prefixes CHECK-C
// Ensure struct declarations are emitted as typedefs before functions

struct Point {
    var x: Int
    var y: Int
}

struct Flags {
    var a: Bool
    var b: Bool
}

func main() -> Int32 {
    return Int32(0)
}

// CHECK-C: typedef struct Point {
// CHECK-C:     int64_t x;
// CHECK-C:     int64_t y;
// CHECK-C: } Point;

// CHECK-C: typedef struct Flags {
// CHECK-C:     bool a;
// CHECK-C:     bool b;
// CHECK-C: } Flags;
