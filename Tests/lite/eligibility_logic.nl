// RUN: %newlang %s -o %t && %t | %FileCheck %s --check-prefixes CHECK-OUTPUT
// Real-ish business logic: eligibility determination with nested conditions

@extern(c)
func printf(_ format: *Int8, ...)

// Determine eligibility score based on income, credit score, and flags
// Returns: 0=reject, 1=review, 2=approve
func eligibility(_ income: Int, _ credit: Int, _ hasDebt: Bool, _ isStudent: Bool) -> Int {
    // Hard reject if credit too low
    if credit < 500 { return 0 }

    // Approve if strong metrics and no major debt
    if income > 80000 && credit >= 700 && !hasDebt {
        return 2
    }

    // Students with decent credit and some income -> review
    if isStudent && credit >= 650 && income >= 15000 {
        return 1
    }

    // Otherwise, review if OK metrics; else reject
    if income >= 40000 && credit >= 600 {
        return 1
    }
    return 0
}

func main() -> Int32 {
    printf("A=%lld\n", eligibility(120000, 750, false, false)) // Approve
    printf("B=%lld\n", eligibility(18000, 680, false, true))  // Review
    printf("C=%lld\n", eligibility(35000, 610, true, false))  // Reject
    printf("D=%lld\n", eligibility(45000, 620, true, false))  // Review
    printf("E=%lld\n", eligibility(30000, 450, false, false)) // Reject (low credit)
    return Int32(0)
}

// CHECK-OUTPUT: A=2
// CHECK-OUTPUT: B=1
// CHECK-OUTPUT: C=0
// CHECK-OUTPUT: D=1
// CHECK-OUTPUT: E=0

