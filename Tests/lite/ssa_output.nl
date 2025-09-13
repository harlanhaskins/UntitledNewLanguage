// RUN: %newlang %s --emit nir 2>/dev/null | %FileCheck %s  
// Test NIR generation patterns for basic functions

// CHECK: nir @test : $(Int, Int) -> Int {
// CHECK: entry(%{{[0-9]+}} : $Int, %{{[0-9]+}} : $Int):
// CHECK: %{{[0-9]+}} = integer_add %{{[0-9]+}} : $Int, %{{[0-9]+}} : $Int
// CHECK: return %{{[0-9]+}} : $Int

func test(_ x: Int, _ y: Int) -> Int {
    return x + y
}

func main() -> Int32 {
    return Int32(0)
}
