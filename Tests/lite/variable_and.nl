// Test short-circuiting with variable assignment (no return)
func test() -> Bool {
    var result = false && true
    return result
}

func main() -> Int32 {
    return Int32(0)
}