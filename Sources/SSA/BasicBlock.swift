import Types

/// A basic block in SSA form with parameters (replacing traditional phi nodes)
public final class BasicBlock: Equatable, SSAVisitable {
    public let name: String
    public var parameters: [BlockParameter]
    public var instructions: [any SSAInstruction]
    public var terminator: (any Terminator)?
    public weak var function: SSAFunction?

    public init(name: String, parameterTypes: [any TypeProtocol] = [], function: SSAFunction? = nil) {
        self.name = name
        self.function = function
        instructions = []
        terminator = nil

        // Initialize parameters array first
        parameters = []

        // Then create parameters for this block
        let params = parameterTypes.enumerated().map { index, type in
            BlockParameter(
                type: type,
                block: self,
                index: index
            )
        }

        // Update the parameters array
        parameters = params
    }

    /// Add an instruction to this block
    public func add(_ instruction: any SSAInstruction) {
        precondition(terminator == nil, "Cannot add instructions after terminator")
        instructions.append(instruction)
    }

    /// Set the terminator for this block
    public func setTerminator(_ terminator: any Terminator) {
        precondition(self.terminator == nil, "Block already has a terminator")
        self.terminator = terminator
    }
    
    /// Clear the terminator for this block (used for replacing terminators)
    public func clearTerminator() {
        self.terminator = nil
    }

    /// Get all successors of this block
    public var successors: [BasicBlock] {
        return terminator?.successors ?? []
    }

    public static func ==(lhs: BasicBlock, rhs: BasicBlock) -> Bool {
        lhs === rhs
    }

    public func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

/// Base protocol for block terminators (instructions that end a block)
public protocol Terminator: SSAVisitable {
    var successors: [BasicBlock] { get }
}

/// Unconditional jump to another block with arguments
public final class JumpTerm: Terminator {
    public let target: BasicBlock
    public let arguments: [any SSAValue]

    public var successors: [BasicBlock] { [target] }

    public init(target: BasicBlock, arguments: [any SSAValue] = []) {
        self.target = target
        self.arguments = arguments

        // Validate argument count matches target's parameter count
        precondition(arguments.count == target.parameters.count,
                     "Argument count (\(arguments.count)) must match target parameter count (\(target.parameters.count))")
    }

    public func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Conditional branch based on a boolean value
public final class BranchTerm: Terminator {
    public let condition: any SSAValue
    public let trueTarget: BasicBlock
    public let falseTarget: BasicBlock
    public let trueArguments: [any SSAValue]
    public let falseArguments: [any SSAValue]

    public var successors: [BasicBlock] { [trueTarget, falseTarget] }

    public init(condition: any SSAValue,
                trueTarget: BasicBlock, trueArguments: [any SSAValue] = [],
                falseTarget: BasicBlock, falseArguments: [any SSAValue] = [])
    {
        self.condition = condition
        self.trueTarget = trueTarget
        self.falseTarget = falseTarget
        self.trueArguments = trueArguments
        self.falseArguments = falseArguments

        // Validate argument counts
        precondition(trueArguments.count == trueTarget.parameters.count,
                     "True branch argument count must match target parameter count")
        precondition(falseArguments.count == falseTarget.parameters.count,
                     "False branch argument count must match target parameter count")
    }

    public func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}

/// Return from function
public final class ReturnTerm: Terminator, SSAVisitable {
    public let value: (any SSAValue)?

    public var successors: [BasicBlock] { [] }

    public init(value: (any SSAValue)? = nil) {
        self.value = value
    }

    public func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result { walker.visit(self) }
}
