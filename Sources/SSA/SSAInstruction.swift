import Types

/// Base protocol for all SSA instructions. Instructions are SSA values.
public protocol SSAInstruction: SSAValue, SSAVisitable {
    var operands: [any SSAValue] { get }
}

/// Arithmetic operations
public final class BinaryOp: SSAInstruction {
    public enum Operator: String {
        case add, subtract, multiply, divide, modulo
        case logicalAnd, logicalOr
        case equal, notEqual, lessThan, lessThanOrEqual, greaterThan, greaterThanOrEqual
    }

    public let `operator`: Operator
    public let left: any SSAValue
    public let right: any SSAValue
    public let type: any TypeProtocol

    public var operands: [any SSAValue] { [left, right] }

    public init(operator: Operator, left: any SSAValue, right: any SSAValue, type: any TypeProtocol) {
        self.operator = `operator`
        self.left = left
        self.right = right
        self.type = type
    }

    public func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Unary operations
public final class UnaryOp: SSAInstruction {
    public enum Operator: String {
        case negate
        case logicalNot
    }

    public let `operator`: Operator
    public let operand: any SSAValue
    public let type: any TypeProtocol

    public var operands: [any SSAValue] { [operand] }

    public init(operator: Operator, operand: any SSAValue, type: any TypeProtocol) {
        self.operator = `operator`
        self.operand = operand
        self.type = type
    }

    public func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Extract a field value from a struct value
public final class FieldExtractInst: SSAInstruction {
    public let base: any SSAValue
    public let fieldName: String
    public let type: any TypeProtocol

    public var operands: [any SSAValue] { [base] }

    public init(base: any SSAValue, fieldName: String, type: any TypeProtocol) {
        self.base = base
        self.fieldName = fieldName
        self.type = type
    }

    public func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Compute the address of a nested field path (GEP-like)
public final class FieldAddressInst: SSAInstruction {
    public let baseAddress: any SSAValue // should be a pointer to a struct
    public let fieldPath: [String] // ordered list of field names to traverse
    public let type: any TypeProtocol

    public var operands: [any SSAValue] { [baseAddress] }

    public init(baseAddress: any SSAValue, fieldPath: [String], type: any TypeProtocol) {
        self.baseAddress = baseAddress
        self.fieldPath = fieldPath
        self.type = type
    }

    public func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Function call instruction
public final class CallInst: SSAInstruction {
    public let function: String // function name or reference
    public let arguments: [any SSAValue]
    public let type: any TypeProtocol

    public var operands: [any SSAValue] { arguments }

    public init(function: String, arguments: [any SSAValue], type: any TypeProtocol) {
        self.function = function
        self.arguments = arguments
        self.type = type
    }

    public func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Allocate memory on the stack (like LLVM's alloca)
public final class AllocaInst: SSAInstruction {
    public let userProvidedName: String?
    public let allocatedType: any TypeProtocol
    public let type: any TypeProtocol

    public var operands: [any SSAValue] { [] }

    public init(
        allocatedType: any TypeProtocol,
        userProvidedName: String? = nil
    ) {
        self.allocatedType = allocatedType
        self.userProvidedName = userProvidedName
        type = PointerType(pointee: allocatedType)
    }

    public func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Load from a memory location
public final class LoadInst: SSAInstruction {
    public let address: any SSAValue // should point to an alloca or similar
    public let type: any TypeProtocol

    public var operands: [any SSAValue] { [address] }

    public init(address: any SSAValue, type: any TypeProtocol) {
        self.address = address
        self.type = type
    }

    public func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Store to a memory location
public final class StoreInst: SSAInstruction {
    public let address: any SSAValue // should point to an alloca or similar
    public let value: any SSAValue
    public let type: any TypeProtocol = VoidType() // stores don't produce values

    public var operands: [any SSAValue] { [address, value] }

    public init(address: any SSAValue, value: any SSAValue) {
        self.address = address
        self.value = value
    }

    public func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Cast/conversion instruction
public final class CastInst: SSAInstruction {
    public let value: any SSAValue
    public let targetType: any TypeProtocol
    public let type: any TypeProtocol

    public var operands: [any SSAValue] { [value] }

    public init(value: any SSAValue, targetType: any TypeProtocol) {
        self.value = value
        self.targetType = targetType
        type = targetType
    }

    public func accept<V: SSAFunctionVisitor>(_ visitor: V) -> V.Result {
        visitor.visit(self)
    }
}
