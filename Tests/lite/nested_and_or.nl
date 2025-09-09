// Test nested short-circuiting: (false && true) || true
func test() -> Bool {
    return (false && true) || true
}

func main() -> Int32 {
    return Int32(0)
}