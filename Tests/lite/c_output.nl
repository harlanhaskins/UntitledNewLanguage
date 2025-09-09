// RUN: %newlang %s --emit c 2>/dev/null | %FileCheck %s  
// Test C code generation patterns

// CHECK: #include <stdbool.h>
// CHECK: #include <stdint.h>
// CHECK: int64_t test(int64_t {{.*}}, int64_t {{.*}}) {
// CHECK: {{.*}} = {{.*}} + {{.*}};
// CHECK: return {{.*}};
// CHECK: }

func test(_ x: Int, _ y: Int) -> Int {
    return x + y
}

func main() -> Int32 {
    return Int32(0)
}
