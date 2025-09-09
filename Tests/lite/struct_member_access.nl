// RUN: %newlang %s --emit-c 2>/dev/null | %FileCheck %s --check-prefixes CHECK-C
// RUN: %newlang %s -o %t && %t
// Member access read-only via GEP-like lowering

struct Inner {
    var a: Int
    var b: Int
}

struct Outer {
    var i: Inner
    var c: Int
}

func sumInner(_ inn: Inner) -> Int {
    // Can't do field write yet; just read
    return inn.a + inn.b
}

func main() -> Int32 { return Int32(0) }

// CHECK-C: typedef struct Inner {
// CHECK-C:     int64_t a;
// CHECK-C:     int64_t b;
// CHECK-C: } Inner;
// CHECK-C: typedef struct Outer {
// CHECK-C:     Inner i;
// CHECK-C:     int64_t c;
// CHECK-C: } Outer;
