// RUN: %newlang %s -o /dev/null
// Test basic arithmetic operations

func add(_ x: Int, _ y: Int) -> Int {
    return x + y
}

func subtract(_ x: Int, _ y: Int) -> Int {
    return x - y
}

func multiply(_ x: Int, _ y: Int) -> Int {
    return x * y
}

func divide(_ x: Int, _ y: Int) -> Int {
    return x / y
}

func main() -> Int32 {
    var result = add(5, 3)
    result = subtract(10, 4)
    result = multiply(6, 7)
    result = divide(20, 4)
    return Int32(0)
}
