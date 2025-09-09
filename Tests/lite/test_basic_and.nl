// Test basic && short-circuiting
func main() -> Int32 {
    if (false && true) == false {
        return Int32(0)  // PASS
    } else {
        return Int32(1)  // FAIL
    }
}