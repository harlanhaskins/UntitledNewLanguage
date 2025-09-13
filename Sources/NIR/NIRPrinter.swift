import Types

/// Maps NIR values to their dynamic names
public final class ValueNameMap {
    var uniqueNames = UniqueNameMap()
    private var valueToName: [ObjectIdentifier: String] = [:]

    public init() {}

    public func getName(for value: any NIRValue) -> String {
        let id = ObjectIdentifier(value)

        if let existing = valueToName[id] {
            return existing
        }

        var userProvidedName: String?
        if let alloca = value as? AllocaInst {
            userProvidedName = alloca.userProvidedName
        }

        // All NIR values get sequential numbering
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

/// Pretty-prints NIR in a SIL-like format
public enum NIRPrinter {
    public static func printFunction(_ function: NIRFunction) -> String {
        let nameMap = ValueNameMap()
        let printer = Printer(nameMap: nameMap)
        return function.accept(printer)
    }

    public static func printInstruction(_ instruction: any NIRInstruction, nameMap: ValueNameMap) -> String {
        let printer = Printer(nameMap: nameMap)
        return instruction.accept(printer)
    }

    // Internal visitor that formats NIR to text
    private final class Printer: NIRFunctionVisitor {
        typealias Result = String

        let nameMap: ValueNameMap
        init(nameMap: ValueNameMap) { self.nameMap = nameMap }

        func visit(_ node: NIRFunction) -> String {
            var output = ""
            output += "nir @\(node.name) : $("
            let paramTypeStrs = node.parameters.map { formatType($0.type) }
            output += paramTypeStrs.joined(separator: ", ")
            output += ") -> \(formatType(node.returnType)) {\n"
            for block in node.blocks {
                output += block.accept(self)
            }
            output += "}\n"
            return output
        }

        func visit(_ node: BasicBlock) -> String {
            var output = ""
            output += "\(node.name)"
            if !node.parameters.isEmpty {
                output += "("
                let paramStrs = node.parameters.map { param in
                    "\(nameMap.getName(for: param)) : $\(formatType(param.type))"
                }
                output += paramStrs.joined(separator: ", ")
                output += ")"
            }
            output += ":\n"

            for inst in node.instructions {
                output += "  \(inst.accept(self))\n"
            }
            if let term = node.terminator {
                output += "  \(term.accept(self))\n"
            }
            output += "\n"
            return output
        }

        func visit(_ node: AllocaInst) -> String {
            let name = nameMap.getName(for: node)
            return "\(name) = alloca $\(formatType(node.allocatedType))"
        }

        func visit(_ node: LoadInst) -> String {
            let result = nameMap.getName(for: node)
            let addr = formatValue(node.address)
            return "\(result) = load \(addr)"
        }

        func visit(_ node: StoreInst) -> String {
            let value = formatValue(node.value)
            let addr = formatValue(node.address)
            return "store \(value) to \(addr)"
        }

        func visit(_ node: BinaryOp) -> String {
            let result = nameMap.getName(for: node)
            let left = formatValue(node.left)
            let right = formatValue(node.right)
            let op = formatBinaryOp(node.operator)
            return "\(result) = \(op) \(left), \(right)"
        }

        func visit(_ node: UnaryOp) -> String {
            let result = nameMap.getName(for: node)
            let operand = formatValue(node.operand)
            let op = formatUnaryOp(node.operator)
            return "\(result) = \(op) \(operand)"
        }

        func visit(_ node: CallInst) -> String {
            let args = node.arguments.map { formatValue($0) }.joined(separator: ", ")
            if !(node.type is VoidType) {
                let name = nameMap.getName(for: node)
                return "\(name) = apply @\(node.function)(\(args))"
            } else {
                return "apply @\(node.function)(\(args))"
            }
        }

        func visit(_ node: CastInst) -> String {
            let result = nameMap.getName(for: node)
            let value = formatValue(node.value)
            return "\(result) = cast \(value) : $\(formatType(node.value.type)) to $\(formatType(node.targetType))"
        }

        func visit(_ node: FieldExtractInst) -> String {
            let result = nameMap.getName(for: node)
            let base = formatValue(node.base)
            return "\(result) = extract \(base).\(node.fieldName)"
        }

        func visit(_ node: FieldAddressInst) -> String {
            let result = nameMap.getName(for: node)
            let base = formatValue(node.baseAddress)
            return "\(result) = gep \(base) [\(node.fieldPath.joined(separator: "."))]"
        }

        func visit(_ node: JumpTerm) -> String {
            if node.arguments.isEmpty {
                return "br \(node.target.name)"
            } else {
                let args = node.arguments.map { formatValue($0) }.joined(separator: ", ")
                return "br \(node.target.name)(\(args))"
            }
        }

        func visit(_ node: BranchTerm) -> String {
            let cond = formatValue(node.condition)
            var result = "cond_br \(cond), \(node.trueTarget.name)"
            if !node.trueArguments.isEmpty {
                let trueArgs = node.trueArguments.map { formatValue($0) }.joined(separator: ", ")
                result += "(\(trueArgs))"
            }
            result += ", \(node.falseTarget.name)"
            if !node.falseArguments.isEmpty {
                let falseArgs = node.falseArguments.map { formatValue($0) }.joined(separator: ", ")
                result += "(\(falseArgs))"
            }
            return result
        }

        func visit(_ node: ReturnTerm) -> String {
            if let value = node.value {
                return "return \(formatValue(value))"
            } else {
                return "return"
            }
        }

        // Helpers
        private func formatValue(_ value: any NIRValue) -> String {
            let text = switch value {
            case let constant as Constant:
                switch constant.value {
                case .boolean(let b): "\(b)"
                case .string(let s): "\"\(s)\""
                case .integer(let i): "\(i)"
                case .void: "()"
                }
            case is Undef: "undef"
            default: nameMap.getName(for: value)
            }
            return "\(text) : $\(formatType(value.type))"
        }

        private func formatType(_ type: any TypeProtocol) -> String {
            return type.description
        }

        private func formatBinaryOp(_ op: BinaryOp.Operator) -> String {
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

        private func formatUnaryOp(_ op: UnaryOp.Operator) -> String {
            switch op {
            case .negate: return "integer_neg"
            case .logicalNot: return "logical_not"
            }
        }
    }
}
