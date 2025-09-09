// Test: (false && true) && false should return false
// If working correctly, main should return 1 (because test() returns false)
// If broken and always true, main would return 0

func test() -> Bool {
    return (false && true) && false  // Should be false
}

func main() -> Int32 {
    if test() {
        return Int32(0)  // test() returned true (wrong!)
    } else {
        return Int32(1)  // test() returned false (correct!)
    }
}