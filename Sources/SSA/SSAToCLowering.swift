import AST
import Types

/// Maps SSA values to C variable names
private final class SSAValueToCNameMap {
    private var names = UniqueNameMap()
    private var valueToName: [ObjectIdentifier: String] = [:]
    private var nextTempNumber = 0
    private var nextLocalNumber = 0

    func getTempName(for value: any SSAValue) -> String {
        let id = ObjectIdentifier(value)
        
        if let existing = valueToName[id] {
            return existing
        }
        
        let name = names.next(for: "t")
        valueToName[id] = name
        return name
    }

    func getLocalVarName(for value: any SSAValue) -> String {
        let id = ObjectIdentifier(value)
        
        if let existing = valueToName[id] {
            return existing
        }

        var userProvidedName: String?
        if let result = value as? InstructionResult,
           let alloca = result.instruction as? AllocaInst {
            userProvidedName = alloca.userProvidedName
        }

        let name = names.next(for: userProvidedName ?? "local")
        valueToName[id] = name
        return name
    }

    func hasName(for value: any SSAValue) -> Bool {
        let id = ObjectIdentifier(value)
        return valueToName[id] != nil
    }
}

// MARK: - Per-function C emitter
public final class CFunctionEmitter {
    fileprivate var variableNameMap = SSAValueToCNameMap()
    private var ssaNameMap = ValueNameMap()
    private let function: SSAFunction

    public init(function: SSAFunction) {
        self.function = function
    }

    /// Generate the forward declaration line for this function
    public func generateForwardDeclaration() -> String {
        let entryBlockParams = function.blocks.first?.parameters ?? []
        let returnTypeStr = function.name == "main" ? "int" : formatCType(function.returnType)
        var output = "\(returnTypeStr) \(function.name)("
        let paramTypes = entryBlockParams.map { formatCType($0.type) }
        output += paramTypes.isEmpty ? "void" : paramTypes.joined(separator: ", ")
        output += ");\n"
        return output
    }

    /// Generate the full function body (definition)
    public func generateBody() -> String {
        var output = ""

        // Ensure entry block parameters get their names first
        let entryBlockParams = function.blocks.first?.parameters ?? []
        for param in entryBlockParams { _ = variableNameMap.getTempName(for: param) }

        // Signature with named parameters
        let returnTypeStr = function.name == "main" ? "int" : formatCType(function.returnType)
        output += "\(returnTypeStr) \(function.name)("
        let paramStrs = entryBlockParams.map { param in
            let name = variableNameMap.getTempName(for: param)
            return "\(formatCType(param.type)) \(name)"
        }
        output += paramStrs.isEmpty ? "void" : paramStrs.joined(separator: ", ")
        output += ") {\n"

        // Declarations
        let localVars = collectLocalVariables(function)
        for (type, varName) in localVars { output += "    \(formatCType(type)) \(varName);\n" }

        let tempVars = collectTempVariables(function)
        for (type, varName) in tempVars { output += "    \(formatCType(type)) \(varName);\n" }

        if !localVars.isEmpty || !tempVars.isEmpty { output += "\n" }

        // Blocks
        for (index, block) in function.blocks.enumerated() {
            if index > 0 { output += "\n" }
            output += lowerBasicBlock(block, isFirst: index == 0)
        }

        output += "}\n"
        return output
    }

    private func collectLocalVariables(_ function: SSAFunction) -> [(any TypeProtocol, String)] {
        var localVars: [(any TypeProtocol, String)] = []

        for block in function.blocks {
            for instruction in block.instructions {
                if let alloca = instruction as? AllocaInst {
                    let varName = variableNameMap.getLocalVarName(for: alloca.result!)
                    localVars.append((alloca.allocatedType, varName))
                }
            }
        }

        return localVars
    }

    private func collectTempVariables(_ function: SSAFunction) -> [(any TypeProtocol, String)] {
        var tempVars: [(any TypeProtocol, String)] = []

        for (index, block) in function.blocks.enumerated() {
            // Collect block parameters as temporary variables (except entry block which are function params)
            if index > 0 { // Skip entry block parameters
                for param in block.parameters {
                    let varName = variableNameMap.getTempName(for: param)
                    tempVars.append((param.type, varName))
                }
            }
            
            // Collect instruction results
            for instruction in block.instructions {
                if let result = getInstructionResult(instruction) {
                    // Skip alloca and field address results (no C temp needed)
                    if !(instruction is AllocaInst) && !(instruction is FieldAddressInst) {
                        let varName = variableNameMap.getTempName(for: result)
                        tempVars.append((result.type, varName))
                    }
                }
            }
        }

        return tempVars
    }

    private func lowerBasicBlock(_ block: BasicBlock, isFirst: Bool) -> String {
        var output = ""

        // Generate block label (skip for first block)
        if !isFirst {
            output += "\(block.name):\n"
        }

        // Generate instructions
        for instruction in block.instructions {
            let ssaComment = SSAPrinter.printInstruction(instruction, nameMap: ssaNameMap)
            let cCode = lowerInstruction(instruction)
            output += "    // \(ssaComment)\n"
            output += "    \(cCode)\n"
        }

        // Generate terminator
        if let terminator = block.terminator {
            output += "    \(lowerTerminator(terminator))\n"
        }

        return output
    }

    private func lowerInstruction(_ instruction: any SSAInstruction) -> String {
        switch instruction {
        case let alloca as AllocaInst:
            // Alloca is handled by variable declaration, no runtime code needed
            return "// alloca \(formatCType(alloca.allocatedType))"

        case let load as LoadInst:
            let resultName = variableNameMap.getTempName(for: load.result!)
            if let addrRes = load.address as? InstructionResult,
               let fieldAddr = addrRes.instruction as? FieldAddressInst {
                let lvalue = formatLValue(for: fieldAddr)
                return "\(resultName) = \(lvalue);"
            } else {
                let addressName = getValueName(load.address)
                return "\(resultName) = \(addressName);"
            }

        case let store as StoreInst:
            let valueName = getValueName(store.value)
            if let addrRes = store.address as? InstructionResult,
               let fieldAddr = addrRes.instruction as? FieldAddressInst {
                let lvalue = formatLValue(for: fieldAddr)
                return "\(lvalue) = \(valueName);"
            } else {
                let addressName = getValueName(store.address)
                return "\(addressName) = \(valueName);"
            }

        case let binary as BinaryOp:
            let resultName = variableNameMap.getTempName(for: binary.result!)
            let leftName = getValueName(binary.left)
            let rightName = getValueName(binary.right)
            let op = formatBinaryOp(binary.operator)
            return "\(resultName) = \(leftName) \(op) \(rightName);"

        case let unary as UnaryOp:
            let resultName = variableNameMap.getTempName(for: unary.result!)
            let operandName = getValueName(unary.operand)
            let op = formatUnaryOp(unary.operator)
            return "\(resultName) = \(op)\(operandName);"

        case let call as CallInst:
            let args = call.arguments.map { getValueName($0) }.joined(separator: ", ")
            if let result = call.result {
                let resultName = variableNameMap.getTempName(for: result)
                return "\(resultName) = \(call.function)(\(args));"
            } else {
                return "\(call.function)(\(args));"
            }

        case let cast as CastInst:
            let resultName = variableNameMap.getTempName(for: cast.result!)
            let valueName = getValueName(cast.value)
            let targetType = formatCType(cast.targetType)
            return "\(resultName) = (\(targetType))\(valueName);"
        case let field as FieldExtractInst:
            let resultName = variableNameMap.getTempName(for: field.result!)
            let baseName = getValueName(field.base)
            return "\(resultName) = \(baseName).\(field.fieldName);"
        case let fieldAddr as FieldAddressInst:
            // No runtime code for address computation (GEP)
            return "// gep &\(formatLValue(for: fieldAddr))"

        default:
            return "// unknown instruction: \(type(of: instruction))"
        }
    }

    private func lowerTerminator(_ terminator: any Terminator) -> String {
        switch terminator {
        case let jump as JumpTerm:
            var result = ""
            // Assign arguments to target block parameters
            for (i, arg) in jump.arguments.enumerated() {
                let argName = getValueName(arg)
                let paramName = getValueName(jump.target.parameters[i])
                result += "\(paramName) = \(argName); "
            }
            result += "goto \(jump.target.name);"
            return result

        case let branch as BranchTerm:
            let condName = getValueName(branch.condition)
            var result = ""

            // If either side passes arguments to target block parameters, we must
            // emit explicit blocks to assign those parameters before the jump.
            if !branch.trueArguments.isEmpty || !branch.falseArguments.isEmpty {
                result += "if (\(condName)) { "
                // True side assignments
                for (i, arg) in branch.trueArguments.enumerated() {
                    let argName = getValueName(arg)
                    let paramName = getValueName(branch.trueTarget.parameters[i])
                    result += "\(paramName) = \(argName); "
                }
                result += "goto \(branch.trueTarget.name); } else { "
                // False side assignments
                for (i, arg) in branch.falseArguments.enumerated() {
                    let argName = getValueName(arg)
                    let paramName = getValueName(branch.falseTarget.parameters[i])
                    result += "\(paramName) = \(argName); "
                }
                result += "goto \(branch.falseTarget.name); }"
            } else {
                // No arguments on either side; simple conditional branch
                result = "if (\(condName)) goto \(branch.trueTarget.name); else goto \(branch.falseTarget.name);"
            }
            return result

        case let ret as ReturnTerm:
            if let value = ret.value {
                let valueName = getValueName(value)
                return "return \(valueName);"
            } else {
                return "return;"
            }

        default:
            return "// unknown terminator: \(type(of: terminator))"
        }
    }

    private func getValueName(_ value: any SSAValue) -> String {
        switch value {
        case let constant as ConstantValue:
            return formatConstant(constant)
        case let result as InstructionResult:
            if result.instruction is AllocaInst {
                return variableNameMap.getLocalVarName(for: result)
            } else {
                return variableNameMap.getTempName(for: result)
            }
        case let param as BlockParameter:
            return variableNameMap.getTempName(for: param)
        default:
            return "unknown_value"
        }
    }

    private func getInstructionResult(_ instruction: any SSAInstruction) -> InstructionResult? {
        switch instruction {
        case let alloca as AllocaInst:
            return alloca.result
        case let load as LoadInst:
            return load.result
        case let binary as BinaryOp:
            return binary.result
        case let call as CallInst:
            return call.result
        case let cast as CastInst:
            return cast.result
        case let unary as UnaryOp:
            return unary.result
        case let field as FieldExtractInst:
            return field.result
        case let fieldAddr as FieldAddressInst:
            return fieldAddr.result
        default:
            return nil
        }
    }

    private func formatCType(_ type: any TypeProtocol) -> String {
        switch type {
        case is IntType:
            return "int64_t"
        case is Int8Type:
            return "char"
        case is Int32Type:
            return "int32_t"
        case is BoolType:
            return "bool"
        case is VoidType:
            return "void"
        case let s as StructType:
            return s.name
        case let pointer as PointerType:
            return "\(formatCType(pointer.pointee))*"
        default:
            return "void*" // fallback
        }
    }

    /// Build a C lvalue expression for a field address path
    private func formatLValue(for fieldAddr: FieldAddressInst) -> String {
        var baseExpr: String
        if let baseRes = fieldAddr.baseAddress as? InstructionResult,
           baseRes.instruction is AllocaInst {
            baseExpr = variableNameMap.getLocalVarName(for: baseRes)
        } else {
            let baseName = getValueName(fieldAddr.baseAddress)
            if fieldAddr.baseAddress.type is PointerType {
                baseExpr = "(*\(baseName))"
            } else {
                baseExpr = baseName
            }
        }

        var expr = baseExpr
        for f in fieldAddr.fieldPath {
            expr += ".\(f)"
        }
        return expr
    }

    private func formatBinaryOp(_ op: BinaryOp.Operator) -> String {
        switch op {
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "*"
        case .divide: return "/"
        case .modulo: return "%"
        case .logicalAnd: return "&&"
        case .logicalOr: return "||"
        case .equal: return "=="
        case .notEqual: return "!="
        case .lessThan: return "<"
        case .lessThanOrEqual: return "<="
        case .greaterThan: return ">"
        case .greaterThanOrEqual: return ">="
        }
    }

    private func formatUnaryOp(_ op: UnaryOp.Operator) -> String {
        switch op {
        case .negate: return "-"
        case .logicalNot: return "!"
        }
    }

    private func formatConstant(_ constant: ConstantValue) -> String {
        switch constant.value {
        case let intVal as Int:
            return "\(intVal)"
        case let floatVal as Float:
            return "\(floatVal)"
        case let doubleVal as Double:
            return "\(doubleVal)"
        case let boolVal as Bool:
            return boolVal ? "true" : "false"
        case let stringVal as String:
            // Check if this is a string literal or an integer literal
            if constant.type is PointerType {
                // This is a string literal, wrap in quotes
                return "\"\(stringVal)\""
            } else {
                // This is an integer literal stored as string
                return stringVal
            }
        default:
            // Debug: print what we got
            print("DEBUG: Unknown constant value type: \(type(of: constant.value)), value: \(constant.value)")
            return "0" // fallback
        }
    }

    private func formatSSABinaryOp(_ op: BinaryOp.Operator) -> String {
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
}

// MARK: - Module-level C emitter that orchestrates per-function emitters
public struct CEmitter {
    private var forwardDecls: [String] = []
    private var functionBodies: [String] = []

    public init() {}

    public mutating func addFunction(_ function: SSAFunction) {
        let emitter = CFunctionEmitter(function: function)
        forwardDecls.append(emitter.generateForwardDeclaration())
        functionBodies.append(emitter.generateBody())
    }

    public func generatePreamble() -> String {
        var output = ""
        output += "#include <stdbool.h>\n"
        output += "#include <stdint.h>\n"
        return output
    }

    public func generateExternDeclarations(_ declarations: [any Declaration]) -> String {
        var output = ""
        var hasExterns = false
        for declaration in declarations {
            if let externDecl = declaration as? ExternDeclaration {
                if !hasExterns {
                    output += "\n// External function declarations\n"
                    hasExterns = true
                }
                let fn = externDecl.function
                let returnTypeStr = formatCType(fn.resolvedReturnType ?? VoidType())
                var line = "extern \(returnTypeStr) \(fn.name)("
                var paramStrs: [String] = []
                for param in fn.parameters {
                    if param.isVariadic {
                        paramStrs.append("...")
                    } else {
                        let paramType = formatCType(param.type.resolvedType ?? VoidType())
                        paramStrs.append(paramType)
                    }
                }
                line += paramStrs.joined(separator: ", ")
                line += ");\n"
                output += line
            }
        }
        if hasExterns { output += "\n" }
        return output
    }

    /// Emit full C module: preamble, externs, forward decls, and function bodies
    public func emitModule(declarations: [any Declaration]) -> String {
        var output = ""
        output += generatePreamble()
        output += generateExternDeclarations(declarations)

        // Emit typedefs for struct declarations first for readability
        output += generateStructTypedefs(declarations)

        if !forwardDecls.isEmpty {
            output += "// Function forward declarations\n"
            for decl in forwardDecls { output += decl }
            output += "\n"
        }

        for body in functionBodies { output += body + "\n" }
        return output
    }
}

// File-private helper for formatting C types from Types module
fileprivate func formatCType(_ type: any TypeProtocol) -> String {
    switch type {
    case is IntType: return "int64_t"
    case is Int8Type: return "char"
    case is Int32Type: return "int32_t"
    case is BoolType: return "bool"
    case is VoidType: return "void"
    case let pointer as PointerType: return "\(formatCType(pointer.pointee))*"
    default: return "void*"
    }
}

// MARK: - Struct typedef emission
extension CEmitter {
    fileprivate func generateStructTypedefs(_ declarations: [any Declaration]) -> String {
        var output = ""
        for decl in declarations {
            guard let s = decl as? StructDeclaration else { continue }
            // Emit typedef struct Name { fields } Name;
            output += "typedef struct \(s.name) {\n"
            for field in s.fields {
                let cType: String = {
                    if let nominal = field.type as? NominalTypeNode {
                        switch nominal.name {
                        case "Int": return "int64_t"
                        case "Int8": return "char"
                        case "Int32": return "int32_t"
                        case "Bool": return "bool"
                        case "Void": return "void"
                        default: return nominal.name // assume typedef struct or user type
                        }
                    } else if let resolved = field.type?.resolvedType {
                        return formatCType(resolved)
                    } else {
                        return formatCType(UnknownType())
                    }
                }()
                output += "    \(cType) \(field.name);\n"
            }
            output += "} \(s.name);\n\n"
        }
        return output
    }
}
