// RUN: %newlang %s --emit c 2>/dev/null | %FileCheck %s --check-prefixes CHECK-C
// RUN: %newlang %s -o %t && %t | %FileCheck %s --check-prefixes CHECK-OUT

@extern(c)
func printf(_ format: *Int8, ...)

struct Counter {
    var value: Int

    func inc(_ d: Int) {
        value = value + d
    }

    func get() -> Int {
        return value
    }
}

func main() -> Int32 {
    var c: Counter
    c.value = 0
    printf("before=%lld\n", c.get())
    c.inc(5)
    printf("after=%lld\n", c.get())
    return Int32(0)
}

// CHECK-C: typedef struct Counter {
// CHECK-C:     int64_t value;
// CHECK-C: } Counter;
// CHECK-C: void Counter_inc(Counter*
// CHECK-C: int64_t Counter_get(Counter*
// CHECK-C: int main(void) {
// CHECK-C:     c.value = 0;
// CHECK-C:     printf("before=%lld\n", t
// CHECK-C:     Counter_inc(&c, 5);
// CHECK-C:     printf("after=%lld\n", t

// CHECK-OUT: before=0
// CHECK-OUT: after=5
