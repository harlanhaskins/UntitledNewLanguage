import Types

/// Maps SSA values to their dynamic names
public final class ValueNameMap {
    var uniqueNames = UniqueNameMap()
    private var valueToName: [ObjectIdentifier: String] = [:]

    public init() {}

    public func getName(for value: any SSAValue) -> String {
        let id = ObjectIdentifier(value)

        if let existing = valueToName[id] {
            return existing
        }

        var userProvidedName: String?
        if let alloca = value as? AllocaInst {
            userProvidedName = alloca.userProvidedName
        }

        // All SSA values get sequential numbering
        let baseName = userProvidedName ?? ""
        var resolved = uniqueNames.next(for: baseName)
        if resolved.isEmpty {
            resolved = "0"
        }

        let name = "%\(resolved)"

        valueToName[id] = name
        return name
    }
}

/// Pretty-prints SSA in a SIL-like format
public enum SSAPrinter {
    public static func printFunction(_ function: SSAFunction) -> String {
        var output = ""
        let nameMap = ValueNameMap()

        // Function signature
        output += "ssa @\(function.name) : $("
        let paramTypeStrs = function.parameters.map { formatType($0.type) }
        output += paramTypeStrs.joined(separator: ", ")
        output += ") -> \(formatType(function.returnType)) {\n"

        // Print each basic block
        for block in function.blocks {
            output += printBasicBlock(block, nameMap: nameMap)
        }

        output += "}\n"
        return output
    }

    private static func printBasicBlock(_ block: BasicBlock, nameMap: ValueNameMap) -> String {
        var output = ""

        // Block label with parameters
        output += "\(block.name)"
        if !block.parameters.isEmpty {
            output += "("
            let paramStrs = block.parameters.map { param in
                "\(nameMap.getName(for: param)) : $\(formatType(param.type))"
            }
            output += paramStrs.joined(separator: ", ")
            output += ")"
        }
        output += ":\n"

        // Instructions
        for instruction in block.instructions {
            output += "  \(printInstruction(instruction, nameMap: nameMap))\n"
        }

        // Terminator
        if let terminator = block.terminator {
            output += "  \(printTerminator(terminator, nameMap: nameMap))\n"
        }

        output += "\n"
        return output
    }

    public static func printInstruction(_ instruction: any SSAInstruction, nameMap: ValueNameMap) -> String {
        switch instruction {
        case let alloca as AllocaInst:
            let name = nameMap.getName(for: alloca)
            return "\(name) = alloca $\(formatType(alloca.allocatedType))"

        case let load as LoadInst:
            let result = nameMap.getName(for: load)
            let addr = formatValue(load.address, nameMap: nameMap)
            return "\(result) = load \(addr)"

        case let store as StoreInst:
            let value = formatValue(store.value, nameMap: nameMap)
            let addr = formatValue(store.address, nameMap: nameMap)
            return "store \(value) to \(addr)"

        case let binary as BinaryOp:
            let result = nameMap.getName(for: binary)
            let left = formatValue(binary.left, nameMap: nameMap)
            let right = formatValue(binary.right, nameMap: nameMap)
            let op = formatBinaryOp(binary.operator)
            return "\(result) = \(op) \(left), \(right)"

        case let unary as UnaryOp:
            let result = nameMap.getName(for: unary)
            let operand = formatValue(unary.operand, nameMap: nameMap)
            let op = formatUnaryOp(unary.operator)
            return "\(result) = \(op) \(operand)"

        case let call as CallInst:
            let args = call.arguments.map { formatValue($0, nameMap: nameMap) }.joined(separator: ", ")
            if !(call.type is VoidType) {
                let name = nameMap.getName(for: call)
                return "\(name) = apply @\(call.function)(\(args))"
            } else {
                return "apply @\(call.function)(\(args))"
            }

        case let cast as CastInst:
            let result = nameMap.getName(for: cast)
            let value = formatValue(cast.value, nameMap: nameMap)
            return "\(result) = cast \(value) : $\(formatType(cast.value.type)) to $\(formatType(cast.targetType))"

        case let field as FieldExtractInst:
            let result = nameMap.getName(for: field)
            let base = formatValue(field.base, nameMap: nameMap)
            return "\(result) = extract \(base).\(field.fieldName)"

        case let fieldAddr as FieldAddressInst:
            let result = nameMap.getName(for: fieldAddr)
            let base = formatValue(fieldAddr.baseAddress, nameMap: nameMap)
            return "\(result) = gep \(base) [\(fieldAddr.fieldPath.joined(separator: "."))]"

        default:
            return "// unknown instruction: \(type(of: instruction))"
        }
    }

    private static func printTerminator(_ terminator: any Terminator, nameMap: ValueNameMap) -> String {
        switch terminator {
        case let jump as JumpTerm:
            if jump.arguments.isEmpty {
                return "br \(jump.target.name)"
            } else {
                let args = jump.arguments.map { formatValue($0, nameMap: nameMap) }.joined(separator: ", ")
                return "br \(jump.target.name)(\(args))"
            }

        case let branch as BranchTerm:
            let cond = formatValue(branch.condition, nameMap: nameMap)
            var result = "cond_br \(cond), \(branch.trueTarget.name)"
            if !branch.trueArguments.isEmpty {
                let trueArgs = branch.trueArguments.map { formatValue($0, nameMap: nameMap) }.joined(separator: ", ")
                result += "(\(trueArgs))"
            }
            result += ", \(branch.falseTarget.name)"
            if !branch.falseArguments.isEmpty {
                let falseArgs = branch.falseArguments.map { formatValue($0, nameMap: nameMap) }.joined(separator: ", ")
                result += "(\(falseArgs))"
            }
            return result

        case let ret as ReturnTerm:
            if let value = ret.value {
                return "return \(formatValue(value, nameMap: nameMap))"
            } else {
                return "return"
            }

        default:
            return "// unknown terminator: \(type(of: terminator))"
        }
    }

    private static func formatValue(_ value: any SSAValue, nameMap: ValueNameMap) -> String {
        return "\(nameMap.getName(for: value)) : $\(formatType(value.type))"
    }

    private static func formatType(_ type: any TypeProtocol) -> String {
        return type.description
    }

    private static func formatBinaryOp(_ op: BinaryOp.Operator) -> String {
        switch op {
        case .add: return "integer_add"
        case .subtract: return "integer_sub"
        case .multiply: return "integer_mul"
        case .divide: return "integer_div"
        case .modulo: return "integer_mod"
        case .logicalAnd: return "logical_and"
        case .logicalOr: return "logical_or"
        case .equal: return "integer_eq"
        case .notEqual: return "integer_ne"
        case .lessThan: return "integer_lt"
        case .lessThanOrEqual: return "integer_le"
        case .greaterThan: return "integer_gt"
        case .greaterThanOrEqual: return "integer_ge"
        }
    }

    private static func formatUnaryOp(_ op: UnaryOp.Operator) -> String {
        switch op {
        case .negate: return "integer_neg"
        case .logicalNot: return "logical_not"
        }
    }
}
