// RUN: %newlang %s -o /dev/null
// Test boolean operations and variables

func boolTest(_ a: Bool, _ b: Bool) -> Bool {
    return a && b
}

func boolLogic(_ x: Bool) -> Bool {
    var result: Bool = x || false
    result = result && true
    return result
}

func boolLiterals() -> Bool {
    return true
}

func main() -> Int32 {
    var result1 = boolTest(true, false)
    var result2 = boolLogic(true)
    var result3 = boolLiterals()
    return Int32(0)
}