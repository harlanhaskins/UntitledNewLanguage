// RUN: %newlang %s --emit parse 2>/dev/null | %FileCheck %s --check-prefixes CHECK-PARSE

func f(_ x: Int) -> Int { return x }

func main() -> Int32 {
    var y = f(_: 1)
    return Int32(0)
}

// CHECK-PARSE: parse error at {{.*}} '_' is not a valid argument label
