// Test that (false && true) || true actually returns true (exit 0)
// and (true && false) && true returns false (exit 1)
func test1() -> Bool {
    return (false && true) || true  // Should be true
}

func test2() -> Bool {
    return (true && false) && true  // Should be false  
}

func main() -> Int32 {
    var result1 = test1()  // Should be true
    var result2 = test2()  // Should be false
    
    if result1 {
        if result2 {
            return Int32(1)  // Failure: both true, but result2 should be false
        } else {
            return Int32(0)  // Success: result1=true, result2=false
        }
    } else {
        return Int32(1)  // Failure: result1 should be true
    }
}