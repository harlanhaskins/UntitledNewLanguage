// RUN: %newlang %s -o %t && %t
// Real-ish use of unary operators: abs, signum, and boolean negation

func abs(_ x: Int) -> Int {
    if x < 0 {
        return -x
    }
    return x
}

func signum(_ x: Int) -> Int {
    if x == 0 {
        return 0
    } else if x < 0 {
        return -1
    } else {
        return 1
    }
}

func main() -> Int32 {
    // abs
    if abs(0) != 0 { return Int32(1) }
    if abs(5) != 5 { return Int32(2) }
    if abs(-5) != 5 { return Int32(3) }

    // signum
    if signum(0) != 0 { return Int32(4) }
    if signum(7) != 1 { return Int32(5) }
    if signum(-7) != -1 { return Int32(6) }

    // boolean negation and nesting
    var b = true
    if !b { return Int32(7) }
    if !!false { return Int32(8) }

    // mixing unary minus with precedence
    var t = -5 + 2  // (-5) + 2 = -3
    if t != -3 { return Int32(9) }

    // double negation on integers
    var u = -(-10)
    if u != 10 { return Int32(10) }

    return Int32(0)
}

