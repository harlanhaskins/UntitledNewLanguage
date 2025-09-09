// RUN: %newlang %s -o /dev/null
// Test local variable declarations and assignments

func testLocalVar(_ x: Int) -> Int {
    var result: Int = x
    result = result + 1  
    return result
}

func complex(_ x: Int) -> Int {
    var temp: Int = x * 2
    temp = temp + 5
    return temp - 1
}

func main() -> Int32 {
    var result1 = testLocalVar(5)
    var result2 = complex(10)
    return Int32(0)
}