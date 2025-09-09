// RUN: %newlang %s -o /dev/null
// Test nested conditional statements

func testNestedIf(_ x: Int, _ y: Int) -> Int {
    if x > 0 {
        if y > 0 {
            return x + y
        } else {
            return x - y
        }
    } else {
        return 0
    }
}

func main() -> Int32 {
    var result = testNestedIf(5, 3)
    result = testNestedIf(5, 2)
    result = testNestedIf(1, 10)
    return Int32(0)
}