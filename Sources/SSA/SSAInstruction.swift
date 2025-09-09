import Types

/// Base protocol for all SSA instructions
public protocol SSAInstruction {
    var operands: [any SSAValue] { get }
    var result: InstructionResult? { get }
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
    public let result: InstructionResult?

    public var operands: [any SSAValue] { [left, right] }

    public init(operator: Operator, left: any SSAValue, right: any SSAValue, result: InstructionResult?) {
        self.operator = `operator`
        self.left = left
        self.right = right
        self.result = result
    }
}

/// Unary operations
public final class UnaryOp: SSAInstruction {
    public enum Operator: String {
        case negate
        case logicalNot
    }

    public let `operator`: Operator
    public let operand: any SSAValue
    public let result: InstructionResult?

    public var operands: [any SSAValue] { [operand] }

    public init(operator: Operator, operand: any SSAValue, result: InstructionResult?) {
        self.operator = `operator`
        self.operand = operand
        self.result = result
    }
}

/// Extract a field value from a struct value
public final class FieldExtractInst: SSAInstruction {
    public let base: any SSAValue
    public let fieldName: String
    public let result: InstructionResult?

    public var operands: [any SSAValue] { [base] }

    public init(base: any SSAValue, fieldName: String, result: InstructionResult?) {
        self.base = base
        self.fieldName = fieldName
        self.result = result
    }
}

/// Compute the address of a nested field path (GEP-like)
public final class FieldAddressInst: SSAInstruction {
    public let baseAddress: any SSAValue // should be a pointer to a struct
    public let fieldPath: [String]       // ordered list of field names to traverse
    public let result: InstructionResult?

    public var operands: [any SSAValue] { [baseAddress] }

    public init(baseAddress: any SSAValue, fieldPath: [String], result: InstructionResult?) {
        self.baseAddress = baseAddress
        self.fieldPath = fieldPath
        self.result = result
    }
}

/// Function call instruction
public final class CallInst: SSAInstruction {
    public let function: String // function name or reference
    public let arguments: [any SSAValue]
    public let result: InstructionResult?

    public var operands: [any SSAValue] { arguments }

    public init(function: String, arguments: [any SSAValue], result: InstructionResult?) {
        self.function = function
        self.arguments = arguments
        self.result = result
    }
}

/// Allocate memory on the stack (like LLVM's alloca)
public final class AllocaInst: SSAInstruction {
    public let userProvidedName: String?
    public let allocatedType: any TypeProtocol
    public let result: InstructionResult?

    public var operands: [any SSAValue] { [] }

    public init(
        allocatedType: any TypeProtocol,
        userProvidedName: String? = nil,
        result: InstructionResult?
    ) {
        self.allocatedType = allocatedType
        self.userProvidedName = userProvidedName
        self.result = result
    }
}

/// Load from a memory location
public final class LoadInst: SSAInstruction {
    public let address: any SSAValue // should point to an alloca or similar
    public let result: InstructionResult?

    public var operands: [any SSAValue] { [address] }

    public init(address: any SSAValue, result: InstructionResult?) {
        self.address = address
        self.result = result
    }
}

/// Store to a memory location
public final class StoreInst: SSAInstruction {
    public let address: any SSAValue // should point to an alloca or similar
    public let value: any SSAValue
    public let result: InstructionResult? = nil // stores don't produce values

    public var operands: [any SSAValue] { [address, value] }

    public init(address: any SSAValue, value: any SSAValue) {
        self.address = address
        self.value = value
    }
}

/// Cast/conversion instruction
public final class CastInst: SSAInstruction {
    public let value: any SSAValue
    public let targetType: any TypeProtocol
    public let result: InstructionResult?

    public var operands: [any SSAValue] { [value] }

    public init(value: any SSAValue, targetType: any TypeProtocol, result: InstructionResult?) {
        self.value = value
        self.targetType = targetType
        self.result = result
    }
}
