// RUN: %newlang %s --emit c 2>/dev/null | %FileCheck %s --check-prefixes CHECK-C
// RUN: %newlang %s -o %t && %t | %FileCheck %s --check-prefixes CHECK-OUTPUT

@extern(c)
func printf(_ format: *Int8, ...)

struct Point {
    var x: Int
    var y: Int
}

struct Box {
    var p: Point
}

func printPoint(_ p: Point) {
    printf("(%lld,%lld)\n", p.x, p.y)
}

func main() -> Int32 {
    var p: Point
    p.x = 3
    p.y = 4
    printPoint(p)

    var b: Box
    b.p.x = 7
    b.p.y = 9
    printPoint(b.p)
    return Int32(0)
}

// CHECK-C: typedef struct Point {
// CHECK-C: } Point;
// CHECK-C: typedef struct Box {
// CHECK-C: } Box;
// CHECK-C: int main(void) {
// CHECK-C:     p.x = 3;
// CHECK-C:     p.y = 4;
// CHECK-C:     b.p.x = 7;
// CHECK-C:     b.p.y = 9;

// CHECK-OUTPUT: (3,4)
// CHECK-OUTPUT: (7,9)
