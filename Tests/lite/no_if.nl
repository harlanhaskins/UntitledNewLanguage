// RUN: %newlang %s -o /dev/null
// Test without any conditionals

func test(_ x: Int) -> Int {
    return x + 1
}

func main() -> Int32 {
    var result = test(7)
    return Int32(0)
}