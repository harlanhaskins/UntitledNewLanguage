// RUN: %newlang %s -o %t && %t | %FileCheck %s --check-prefixes CHECK-OUTPUT
// Simple validation-style logic using comparisons, logical ops, and !

@extern(c)
func printf(_ format: *Int8, ...)

func boolStr(_ b: Bool) -> *Int8 {
    if b {
        return "true"
    } else {
        return "false"
    }
}

func isValidPassword(_ len: Int, _ hasUpper: Bool, _ hasDigit: Bool) -> Bool {
    // Require at least 8 chars and both upper and digit
    return len >= 8 && (hasUpper && hasDigit)
}

func isWeak(_ len: Int, _ hasUpper: Bool, _ hasDigit: Bool) -> Bool {
    // Weak if not valid but has at least some minimal len
    return !isValidPassword(len, hasUpper, hasDigit) && len >= 4
}

func main() -> Int32 {
    // Case 1: Strong
    var s1 = isValidPassword(12, true, true)
    printf("s1=%s\n", boolStr(s1))

    // Case 2: Weak (missing digit)
    var s2 = isWeak(10, true, false)
    printf("s2=%s\n", boolStr(s2))

    // Case 3: Invalid (too short)
    var s3 = isValidPassword(6, true, true)
    printf("s3=%s\n", boolStr(s3))

    // Case 4: Weak (short but >=4), no upper, has digit
    var s4 = isWeak(5, false, true)
    printf("s4=%s\n", boolStr(s4))

    return Int32(0)
}

// CHECK-OUTPUT: s1=true
// CHECK-OUTPUT: s2=true
// CHECK-OUTPUT: s3=false
// CHECK-OUTPUT: s4=true
