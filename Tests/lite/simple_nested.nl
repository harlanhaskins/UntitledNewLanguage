// Test simple nested expressions with variable assignments
func test1() -> Bool {
    var result1 = (false && true) || true
    return result1
}

func test2() -> Bool {
    var result2 = false && (true || false)
    return result2  
}

func main() -> Int32 {
    return Int32(0)
}