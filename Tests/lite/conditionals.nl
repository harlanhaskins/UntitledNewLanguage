// RUN: %newlang %s
// Test conditional statements (if/else if/else)

func testSimpleIf(_ x: Int) -> Int {
    if x > 5 {
        return 10
    }
    return 0
}

func testIfElse(_ x: Int) -> Int {
    if x > 5 {
        return 10
    } else {
        return 20
    }
}

func testIfElseIf(_ x: Int) -> Int {
    if x > 10 {
        return 1
    } else if x > 5 {
        return 2
    } else {
        return 3
    }
}

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
    var result = testSimpleIf(7)
    result = testIfElse(3)
    result = testIfElseIf(8)
    result = testNestedIf(5, 2)
    return Int32(0)
}