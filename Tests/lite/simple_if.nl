// RUN: %newlang %s
// Test simple conditional statement

func testSimpleIf(_ x: Int) -> Int {
    if x > 5 {
        return 10
    }
    return 0
}

func main() -> Int32 {
    var result = testSimpleIf(7)
    return Int32(0)
}