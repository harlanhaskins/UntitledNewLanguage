import AST
import Types

/// Maps SSA values to C variable names
private final class SSAValueToCNameMap {
    private var names = UniqueNameMap()
    private var valueToName: [ObjectIdentifier: String] = [:]
    private var nextTempNumber = 0
    private var nextLocalNumber = 0

    func getTempName(for value: any SSAValue) -> String {
        let name = names.next(for: "t")
        valueToName[ObjectIdentifier(value)] = name
        return name
    }

    func getLocalVarName(for value: any SSAValue) -> String {
        let name = names.next(for: "local")
        valueToName[ObjectIdentifier(value)] = name
        return name
    }

    func hasName(for value: any SSAValue) -> Bool {
        let id = ObjectIdentifier(value)
        return valueToName[id] != nil
    }
}

/// Lowers SSA functions to C code
public struct CEmitter {
    fileprivate var variableNameMap = SSAValueToCNameMap()
    private var ssaNameMap = ValueNameMap()

    public init() {

    }

    /// Generate C preamble (standard headers)
    public func generatePreamble() -> String {
        var output = ""
        output += "#include <stdbool.h>\n"
        output += "#include <stdint.h>\n"
        return output
    }
    
    /// Generate C code for extern function declarations
    public func generateExternDeclarations(_ declarations: [any Declaration]) -> String {
        var output = ""

        // Generate extern function declarations
        var hasExterns = false
        for declaration in declarations {
            if let externDecl = declaration as? ExternDeclaration {
                if !hasExterns {
                    output += "\n// External function declarations\n"
                    hasExterns = true
                }
                output += generateExternFunctionDeclaration(externDecl.function)
            }
        }

        if hasExterns {
            output += "\n"
        }

        return output
    }
    
    /// Generate forward declarations for all functions
    public func generateForwardDeclarations(_ functions: [SSAFunction]) -> String {
        var output = ""
        
        if !functions.isEmpty {
            output += "// Function forward declarations\n"
            
            for function in functions {
                output += generateFunctionSignature(function)
                output += ";\n"
            }
            
            output += "\n"
        }
        
        return output
    }

    /// Generate a C declaration for an extern function
    private func generateExternFunctionDeclaration(_ function: FunctionDeclaration) -> String {
        let returnTypeStr = formatCType(function.resolvedReturnType ?? VoidType())
        var output = "extern \(returnTypeStr) \(function.name)("

        var paramStrs: [String] = []
        for param in function.parameters {
            if param.isVariadic {
                paramStrs.append("...")
            } else {
                let paramType = formatCType(param.type.resolvedType ?? VoidType())
                paramStrs.append(paramType)
            }
        }

        output += paramStrs.joined(separator: ", ")
        output += ");\n"

        return output
    }

    /// Generate function signature (without semicolon or opening brace)
    private func generateFunctionSignature(_ function: SSAFunction) -> String {
        // Use entry block parameters instead of function parameters
        let entryBlockParams = function.blocks.first?.parameters ?? []

        // Function signature (handle main function specially)
        let returnTypeStr = function.name == "main" ? "int" : formatCType(function.returnType)
        var output = "\(returnTypeStr) \(function.name)("

        // For forward declarations, we don't need parameter names, just types
        let paramTypes = entryBlockParams.map { param in
            return formatCType(param.type)
        }

        if paramTypes.isEmpty {
            output += "void"
        } else {
            output += paramTypes.joined(separator: ", ")
        }
        output += ")"

        return output
    }

    public func lowerFunction(_ function: SSAFunction) -> String {
        var output = ""
        let nameMap = SSAValueToCNameMap()

        // Use entry block parameters instead of function parameters
        let entryBlockParams = function.blocks.first?.parameters ?? []

        // Ensure entry block parameters get their names first
        for param in entryBlockParams {
            _ = nameMap.getTempName(for: param)
        }

        // Generate function signature with parameter names for definition
        let returnTypeStr = function.name == "main" ? "int" : formatCType(function.returnType)
        output += "\(returnTypeStr) \(function.name)("

        let paramStrs = entryBlockParams.map { param in
            let paramName = nameMap.getTempName(for: param) // This will return existing name
            return "\(formatCType(param.type)) \(paramName)"
        }

        if paramStrs.isEmpty {
            output += "void"
        } else {
            output += paramStrs.joined(separator: ", ")
        }
        output += ") {\n"

        // Collect all local variables needed (from alloca instructions) using same nameMap
        let localVars = collectLocalVariables(function)

        // Declare local variables
        for (type, varName) in localVars {
            output += "    \(formatCType(type)) \(varName);\n"
        }

        // Collect temporary variables for instruction results using same nameMap
        let tempVars = collectTempVariables(function)
        for (type, varName) in tempVars {
            output += "    \(formatCType(type)) \(varName);\n"
        }

        if !localVars.isEmpty || !tempVars.isEmpty {
            output += "\n"
        }

        // Generate code for each basic block
        for (index, block) in function.blocks.enumerated() {
            if index > 0 {
                output += "\n"
            }
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
                    // Skip alloca results as they're handled as local vars
                    if !(instruction is AllocaInst) {
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
            let addressName = getValueName(load.address)
            return "\(resultName) = \(addressName);"

        case let store as StoreInst:
            let valueName = getValueName(store.value)
            let addressName = getValueName(store.address)
            return "\(addressName) = \(valueName);"

        case let binary as BinaryOp:
            let resultName = variableNameMap.getTempName(for: binary.result!)
            let leftName = getValueName(binary.left)
            let rightName = getValueName(binary.right)
            let op = formatBinaryOp(binary.operator)
            return "\(resultName) = \(leftName) \(op) \(rightName);"

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
            
            // Handle true branch arguments
            if !branch.trueArguments.isEmpty {
                result += "if (\(condName)) { "
                for (i, arg) in branch.trueArguments.enumerated() {
                    let argName = getValueName(arg)
                    let paramName = getValueName(branch.trueTarget.parameters[i])
                    result += "\(paramName) = \(argName); "
                }
                result += "goto \(branch.trueTarget.name); } else { "
                
                // Handle false branch arguments
                for (i, arg) in branch.falseArguments.enumerated() {
                    let argName = getValueName(arg)
                    let paramName = getValueName(branch.falseTarget.parameters[i])
                    result += "\(paramName) = \(argName); "
                }
                result += "goto \(branch.falseTarget.name); }"
            } else {
                // No arguments, use simple branch
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
        case let pointer as PointerType:
            return "\(formatCType(pointer.pointee))*"
        default:
            return "void*" // fallback
        }
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
