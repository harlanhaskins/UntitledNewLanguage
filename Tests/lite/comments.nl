// RUN: %newlang %s
// Test comment parsing in various positions

// This is a comment at the start
func test(_ x: Int) -> Int {
    // Another comment inside function
    return x + 1  // End of line comment
}

// Comment before main
func main() -> Int32 {
    var result = test(5) // Comment after code
    return Int32(0)
}