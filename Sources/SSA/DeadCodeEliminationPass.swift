import Base
import Types

/// Transform pass that removes dead/unused variables from SSA functions
public final class DeadCodeEliminationPass: SSAFunctionTransformPass {
    public typealias Result = Void

    private var removedCount = 0

    public init() {}

    public func transform(_ function: inout SSAFunction) {
        var didChange = true
        removedCount = 0

        // Keep iterating until no more changes (in case removing one instruction enables removing others)
        while didChange {
            didChange = eliminateDeadInstructions(&function)
        }

        if removedCount > 0 {
            print("Dead code elimination: removed \(removedCount) unused instruction\(removedCount == 1 ? "" : "s") from function '\(function.name)'")
        }
    }

    /// Remove dead instructions and return whether any changes were made
    private func eliminateDeadInstructions(_ function: inout SSAFunction) -> Bool {
        var changed = false

        for block in function.blocks {
            var instructionsToRemove: [Int] = []

            // Check each instruction for deadness
            for (index, instruction) in block.instructions.enumerated() {
                if isDeadInstruction(instruction, in: function) {
                    instructionsToRemove.append(index)
                    changed = true
                    removedCount += 1
                }
            }

            // Remove instructions in reverse order to maintain indices
            for index in instructionsToRemove.reversed() {
                block.instructions.remove(at: index)
            }
        }

        return changed
    }

    /// Check if an instruction is dead (unused)
    private func isDeadInstruction(_ instruction: any SSAInstruction, in function: SSAFunction) -> Bool {
        // Instructions without results are considered side-effecting and shouldn't be removed
        guard let result = instruction.result else {
            return false
        }

        // Don't remove certain types of instructions even if unused
        switch instruction {
        case is CallInst:
            // Function calls might have side effects, so don't remove them
            return false
        default:
            break
        }

        // Check if the result is used anywhere
        return !isValueUsed(result, in: function)
    }

    /// Check if an SSA value is used anywhere in the function
    private func isValueUsed(_ value: any SSAValue, in function: SSAFunction) -> Bool {
        for block in function.blocks {
            // Check instructions
            for instruction in block.instructions {
                for operand in instruction.operands {
                    if isSameValue(operand, value) {
                        return true
                    }
                }
            }

            // Check terminators
            if let terminator = block.terminator {
                switch terminator {
                case let returnTerm as ReturnTerm:
                    if let returnValue = returnTerm.value, isSameValue(returnValue, value) {
                        return true
                    }
                case let branchTerm as BranchTerm:
                    if isSameValue(branchTerm.condition, value) {
                        return true
                    }
                default:
                    break
                }
            }
        }

        return false
    }

    /// Check if two SSA values refer to the same thing
    private func isSameValue(_ a: any SSAValue, _ b: any SSAValue) -> Bool {
        return a === b
    }
}
