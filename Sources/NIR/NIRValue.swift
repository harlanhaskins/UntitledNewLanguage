import Types

/// Represents a value in NIR form - could be a parameter, instruction itself, or constant
public protocol NIRValue: AnyObject {
    var type: any TypeProtocol { get }
}

/// A parameter to a basic block (replaces traditional phi nodes)
public final class BlockParameter: NIRValue {
    public let type: any TypeProtocol
    public let block: BasicBlock
    public let index: Int

    public init(type: any TypeProtocol, block: BasicBlock, index: Int) {
        self.type = type
        self.block = block
        self.index = index
    }
}

/// An undefined value
public final class Undef: NIRValue {
    public let type: any TypeProtocol
    public init(type: any TypeProtocol = UnknownType()) {
        self.type = type
    }
}

/// A constant NIR value
public final class Constant: NIRValue {
    public enum Value {
        case integer(Int)
        case boolean(Bool)
        case string(String)
        case void
    }
    public let type: any TypeProtocol
    public let value: Value

    public init(type: any TypeProtocol, value: Value) {
        self.type = type
        self.value = value
    }

    public init(type: any TypeProtocol, value: String) {
        self.type = type
        self.value = .string(value)
    }

    public init<I: BinaryInteger>(type: any TypeProtocol, value: I) {
        self.type = type
        self.value = .integer(Int(value))
    }

    public init(type: any TypeProtocol, value: Bool) {
        self.type = type
        self.value = .boolean(value)
    }

    public init(type: any TypeProtocol) {
        self.type = type
        self.value = .void
    }
}
