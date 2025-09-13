// RUN: %newlang %s --emit nir 2>/dev/null | %FileCheck %s  
// Test NIR generation for conditional statements

// CHECK: nir @test : $(Int) -> Int {
// CHECK: entry(%{{[0-9]+}} : $Int):
// CHECK: %{{[0-9]+}} = integer_gt %{{[0-9]+}} : $Int, %{{[0-9]+}} : $Int
// CHECK: cond_br %{{[0-9]+}} : $Bool, then, merge
// CHECK: merge:
// CHECK: return %{{[0-9]+}} : $Int
// CHECK: then:
// CHECK: return %{{[0-9]+}} : $Int

func test(_ x: Int) -> Int {
    if x > 5 {
        return 10
    }
    return 0
}

func main() -> Int32 {
    return Int32(0)
}
