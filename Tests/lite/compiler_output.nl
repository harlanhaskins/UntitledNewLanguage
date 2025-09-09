// RUN: %newlang %s -o /dev/null 2>&1 | %FileCheck %s
// Test compiler output messages and success patterns

// CHECK: === NEWLANG COMPILER ===
// CHECK: Warning: unused variable of type 'Int' in function 'main' (written 1 time but never read)
// CHECK: Note: Function 'main': 1 unused variable (all write-only)
// CHECK: Compiling to executable...
// CHECK: ✅ Compilation successful! Output: /dev/null

func test(_ x: Int) -> Int {
    return x + 1
}

func main() -> Int32 {
    var unused = test(5)
    return Int32(0)
}