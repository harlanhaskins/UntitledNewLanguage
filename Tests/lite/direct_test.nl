// Direct test of nested short-circuit - no if statements
func main() -> Int32 {
    // Test: ((false && true) || true) should be true
    // If true, cast to 0. If false, cast to 1
    return Int32(((false && true) || true))
}