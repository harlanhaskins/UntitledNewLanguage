// RUN: %newlang %s
// Test complex conditions with multiple logical operators

func testComplexConditions(_ x: Int, _ y: Int) -> Int {
    if x > 10 && y > 5 {
        return 1
    } else if x < 5 || y < 0 {
        return 2
    } else if x == y {
        return 3
    } else {
        return 4
    }
}

func main() -> Int32 {
    var result = testComplexConditions(15, 10)
    result = testComplexConditions(2, 8)
    result = testComplexConditions(7, 7)
    result = testComplexConditions(8, 3)
    return Int32(0)
}