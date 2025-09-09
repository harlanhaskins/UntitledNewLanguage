import Base
import Types

/// Function pass that detects unused variables and emits diagnostics
public final class UnusedVariableFunctionPass: SSAFunctionAnalysisPass {
    public typealias Result = Void

    public init() {}

    public func analyze(_ function: SSAFunction, diagnostics: DiagnosticEngine) {
        // First, collect all alloca instructions
        var allocas: [(AllocaInst, BasicBlock)] = []

        for block in function.blocks {
            for instruction in block.instructions {
                if let alloca = instruction as? AllocaInst {
                    allocas.append((alloca, block))
                }
            }
        }

        // For each alloca, check if it's ever loaded from
        var unusedCount = 0
        var uninitializedCount = 0
        var writeOnlyCount = 0

        for (alloca, _) in allocas {
            guard let allocaResult = alloca.result else { continue }

            let usage = analyzeVariableUsage(allocaResult, in: function)

            if !usage.isLoaded {
                unusedCount += 1
                let typeString = formatType(alloca.allocatedType)

                if usage.storeCount == 0 {
                    // Variable is allocated but never used
                    uninitializedCount += 1
                    diagnostics.unusedVariable(
                        function: function.name,
                        type: typeString,
                        kind: .uninitialized
                    )
                } else {
                    // Variable is written to but never read from
                    writeOnlyCount += 1
                    diagnostics.unusedVariable(
                        function: function.name,
                        type: typeString,
                        kind: .writeOnly(storeCount: usage.storeCount)
                    )
                }
            }
        }

        // Emit a summary if there were unused variables
        if unusedCount > 0 {
            diagnostics.unusedVariableSummary(
                function: function.name,
                totalUnused: unusedCount,
                uninitialized: uninitializedCount,
                writeOnly: writeOnlyCount
            )
        }
    }

    /// Usage analysis for a specific variable
    private struct VariableUsage {
        let isLoaded: Bool
        let storeCount: Int
        let loadCount: Int
    }

    private func analyzeVariableUsage(_ variable: any SSAValue, in function: SSAFunction) -> VariableUsage {
        var isLoaded = false
        var storeCount = 0
        var loadCount = 0

        // Walk through all instructions in all blocks
        for block in function.blocks {
            for instruction in block.instructions {
                switch instruction {
                case let load as LoadInst:
                    // Check if this load is from our variable
                    if isSameValue(load.address, variable) {
                        isLoaded = true
                        loadCount += 1
                    }

                case let store as StoreInst:
                    // Check if this store is to our variable
                    if isSameValue(store.address, variable) {
                        storeCount += 1
                    }

                default:
                    // Check other instruction operands for uses
                    for operand in instruction.operands {
                        if isSameValue(operand, variable) {
                            // This is a use, but not a load - could be address taken, etc.
                            // For now, we'll consider this as "used"
                            isLoaded = true
                        }
                    }
                }
            }
        }

        return VariableUsage(isLoaded: isLoaded, storeCount: storeCount, loadCount: loadCount)
    }

    /// Check if two SSA values refer to the same thing
    private func isSameValue(_ a: any SSAValue, _ b: any SSAValue) -> Bool {
        // Use object identity for SSA values since they should be unique
        return a === b
    }

    private func formatType(_ type: any TypeProtocol) -> String {
        switch type {
        case is IntType: return "Int"
        case is Int8Type: return "Int8"
        case is Int32Type: return "Int32"
        case is BoolType: return "Bool"
        case is VoidType: return "Void"
        case let pointer as PointerType: return "*\(formatType(pointer.pointee))"
        default: return "\(type.typeId)"
        }
    }
}
