import Base
import Types

public extension DiagnosticEngine {
    func ssaCannotComputeAddress(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "cannot compute address for value of type '\(type)'", category: "ssa-lowering")
    }

    func ssaCannotStore(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "cannot assign to type '\(type)'", category: "ssa-lowering")
    }

    func ssaAddressOfNonLValue(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "cannot take address of value of type '\(type)'", category: "ssa-lowering")
    }

    func ssaDereferenceNonPointer(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "cannot dereference value of non-pointer type '\(type)'", category: "ssa-lowering")
    }
}
