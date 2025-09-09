// Simple test: (false && true) || true should return true
// If working correctly, main should return 0
// If broken, main should return 1

func test() -> Bool {
    return (false && true) || true
}

func main() -> Int32 {
    if test() {
        return Int32(0)  // Success: returned true  
    } else {
        return Int32(1)  // Failure: returned false
    }
}