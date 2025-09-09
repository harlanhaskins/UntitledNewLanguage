// RUN: %newlang %s
// Test comparison operators

func testComparisons(_ x: Int, _ y: Int) -> Int {
    if x == y {
        return 1
    } else if x != y {
        if x > y {
            return 2
        } else if x < y {
            return 3
        } else if x >= y {
            return 4
        } else if x <= y {
            return 5
        }
    }
    return 0
}

func testLogicalOperators(_ x: Int, _ y: Int) -> Int {
    if x > 0 && y > 0 {
        return 1
    } else if x < 0 || y < 0 {
        return 2
    } else {
        return 3
    }
}

func main() -> Int32 {
    var result = testComparisons(5, 5)
    result = testComparisons(7, 3)
    result = testLogicalOperators(2, 4)
    result = testLogicalOperators(0, 3)
    return Int32(0)
}