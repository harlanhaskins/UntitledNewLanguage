import Types

/// Base protocol for all NIR instructions. Instructions are NIR values.
public protocol NIRInstruction: NIRValue, NIRVisitable {
    var operands: [any NIRValue] { get }
}

/// Arithmetic operations
public final class BinaryOp: NIRInstruction {
    public enum Operator: String {
        case add, subtract, multiply, divide, modulo
        case logicalAnd, logicalOr
        case equal, notEqual, lessThan, lessThanOrEqual, greaterThan, greaterThanOrEqual
    }

    public let `operator`: Operator
    public let left: any NIRValue
    public let right: any NIRValue
    public let type: any TypeProtocol

    public var operands: [any NIRValue] { [left, right] }

    public init(operator: Operator, left: any NIRValue, right: any NIRValue, type: any TypeProtocol) {
        self.operator = `operator`
        self.left = left
        self.right = right
        self.type = type
    }

    public func accept<W: NIRFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Unary operations
public final class UnaryOp: NIRInstruction {
    public enum Operator: String {
        case negate
        case logicalNot
    }

    public let `operator`: Operator
    public let operand: any NIRValue
    public let type: any TypeProtocol

    public var operands: [any NIRValue] { [operand] }

    public init(operator: Operator, operand: any NIRValue, type: any TypeProtocol) {
        self.operator = `operator`
        self.operand = operand
        self.type = type
    }

    public func accept<W: NIRFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Extract a field value from a struct value
public final class FieldExtractInst: NIRInstruction {
    public let base: any NIRValue
    public let fieldName: String
    public let type: any TypeProtocol

    public var operands: [any NIRValue] { [base] }

    public init(base: any NIRValue, fieldName: String, type: any TypeProtocol) {
        self.base = base
        self.fieldName = fieldName
        self.type = type
    }

    public func accept<W: NIRFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Compute the address of a nested field path (GEP-like)
public final class FieldAddressInst: NIRInstruction {
    public let baseAddress: any NIRValue // should be a pointer to a struct
    public let fieldPath: [String] // ordered list of field names to traverse
    public let type: any TypeProtocol

    public var operands: [any NIRValue] { [baseAddress] }

    public init(baseAddress: any NIRValue, fieldPath: [String], type: any TypeProtocol) {
        self.baseAddress = baseAddress
        self.fieldPath = fieldPath
        self.type = type
    }

    public func accept<W: NIRFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Function call instruction
public final class CallInst: NIRInstruction {
    public let function: String // function name or reference
    public let arguments: [any NIRValue]
    public let type: any TypeProtocol

    public var operands: [any NIRValue] { arguments }

    public init(function: String, arguments: [any NIRValue], type: any TypeProtocol) {
        self.function = function
        self.arguments = arguments
        self.type = type
    }

    public func accept<W: NIRFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Allocate memory on the stack (like LLVM's alloca)
public final class AllocaInst: NIRInstruction {
    public let userProvidedName: String?
    public let allocatedType: any TypeProtocol
    public let type: any TypeProtocol

    public var operands: [any NIRValue] { [] }

    public init(
        allocatedType: any TypeProtocol,
        userProvidedName: String? = nil
    ) {
        self.allocatedType = allocatedType
        self.userProvidedName = userProvidedName
        type = PointerType(pointee: allocatedType)
    }

    public func accept<W: NIRFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Load from a memory location
public final class LoadInst: NIRInstruction {
    public let address: any NIRValue // should point to an alloca or similar
    public let type: any TypeProtocol

    public var operands: [any NIRValue] { [address] }

    public init(address: any NIRValue, type: any TypeProtocol) {
        self.address = address
        self.type = type
    }

    public func accept<W: NIRFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Store to a memory location
public final class StoreInst: NIRInstruction {
    public let address: any NIRValue // should point to an alloca or similar
    public let value: any NIRValue
    public let type: any TypeProtocol = VoidType() // stores don't produce values

    public var operands: [any NIRValue] { [address, value] }

    public init(address: any NIRValue, value: any NIRValue) {
        self.address = address
        self.value = value
    }

    public func accept<W: NIRFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Cast/conversion instruction
public final class CastInst: NIRInstruction {
    public let value: any NIRValue
    public let targetType: any TypeProtocol
    public let type: any TypeProtocol

    public var operands: [any NIRValue] { [value] }

    public init(value: any NIRValue, targetType: any TypeProtocol) {
        self.value = value
        self.targetType = targetType
        type = targetType
    }

    public func accept<V: NIRFunctionVisitor>(_ visitor: V) -> V.Result {
        visitor.visit(self)
    }
}
