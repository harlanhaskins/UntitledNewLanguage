import Base
import Types

public extension DiagnosticEngine {
    func nirCannotComputeAddress(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "cannot compute address for value of type '\(type)'", category: "nir-lowering")
    }

    func nirCannotStore(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "cannot assign to type '\(type)'", category: "nir-lowering")
    }

    func nirAddressOfNonLValue(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "cannot take address of value of type '\(type)'", category: "nir-lowering")
    }

    func nirDereferenceNonPointer(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "cannot dereference value of non-pointer type '\(type)'", category: "nir-lowering")
    }
}
