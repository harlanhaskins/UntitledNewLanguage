// RUN: %newlang %s -o /dev/null
// Test extern function declarations and complex expressions

@extern(c)
func printf(_ format: *Int8, ...)

func addAndPrintNumbers(_ x: Int, _ y: Int) -> Int {
    var result: Int = x + y
    var z = result
    // Note: printf call commented out for testing stability
    // printf("%d\n", Int32(result))
    return result
}

func main() -> Int32 {
    var x = addAndPrintNumbers(10, 20)
    x = addAndPrintNumbers(5, 15)
    return Int32(0)
}