import Types

/// Represents a value in SSA form - could be a parameter, instruction result, or constant
public protocol SSAValue: AnyObject {
    var type: any TypeProtocol { get }
}

/// A parameter to a basic block (replaces traditional phi nodes)
public final class BlockParameter: SSAValue {
    public let type: any TypeProtocol
    public let block: BasicBlock
    public let index: Int
    
    public init(type: any TypeProtocol, block: BasicBlock, index: Int) {
        self.type = type
        self.block = block
        self.index = index
    }
}

/// Result of an SSA instruction
public final class InstructionResult: SSAValue {
    public let type: any TypeProtocol
    public let instruction: any SSAInstruction
    
    public init(type: any TypeProtocol, instruction: any SSAInstruction) {
        self.type = type
        self.instruction = instruction
    }
}

/// A constant value
public final class ConstantValue: SSAValue {
    public let type: any TypeProtocol
    public let value: Any
    
    public init(type: any TypeProtocol, value: Any) {
        self.type = type
        self.value = value
    }
}