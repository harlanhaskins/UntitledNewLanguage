import Types
import AST

/// Maps SSA values to C variable names
private final class SSAValueToCNameMap {
    private var valueToName: [ObjectIdentifier: String] = [:]
    private var nextTempNumber = 0
    private var nextLocalNumber = 0
    
    func getTempName(for value: any SSAValue) -> String {
        let id = ObjectIdentifier(value)
        
        if let existing = valueToName[id] {
            return existing
        }
        
        let name = "t\(nextTempNumber)"
        nextTempNumber += 1
        
        valueToName[id] = name
        return name
    }
    
    func getLocalVarName(for value: any SSAValue) -> String {
        let id = ObjectIdentifier(value)
        
        if let existing = valueToName[id] {
            return existing
        }
        
        let name = "local\(nextLocalNumber)"
        nextLocalNumber += 1
        
        valueToName[id] = name
        return name
    }
    
    func hasName(for value: any SSAValue) -> Bool {
        let id = ObjectIdentifier(value)
        return valueToName[id] != nil
    }
}

/// Lowers SSA functions to C code
public struct SSAToCLowering {
    
    public static func lowerFunction(_ function: SSAFunction) -> String {
        var output = ""
        let nameMap = SSAValueToCNameMap()
        
        // Use entry block parameters instead of function parameters
        let entryBlockParams = function.blocks.first?.parameters ?? []
        
        // Ensure entry block parameters get their names first
        for param in entryBlockParams {
            _ = nameMap.getTempName(for: param)
        }
        
        // Function signature  
        let returnTypeStr = formatCType(function.returnType)
        output += "\(returnTypeStr) \(function.name)("
        
        let paramStrs = entryBlockParams.map { param in
            let paramName = nameMap.getTempName(for: param) // This will return existing name
            return "\(formatCType(param.type)) \(paramName)"
        }
        output += paramStrs.joined(separator: ", ")
        output += ") {\n"
        
        // Collect all local variables needed (from alloca instructions) using same nameMap
        let localVars = collectLocalVariables(function, nameMap: nameMap)
        
        // Declare local variables
        for (type, varName) in localVars {
            output += "    \(formatCType(type)) \(varName);\n"
        }
        
        // Collect temporary variables for instruction results using same nameMap
        let tempVars = collectTempVariables(function, nameMap: nameMap)
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
            output += lowerBasicBlock(block, nameMap: nameMap, isFirst: index == 0)
        }
        
        output += "}\n"
        return output
    }
    
    private static func collectLocalVariables(_ function: SSAFunction, nameMap: SSAValueToCNameMap) -> [(any TypeProtocol, String)] {
        var localVars: [(any TypeProtocol, String)] = []
        
        for block in function.blocks {
            for instruction in block.instructions {
                if let alloca = instruction as? AllocaInst {
                    let varName = nameMap.getLocalVarName(for: alloca.result!)
                    localVars.append((alloca.allocatedType, varName))
                }
            }
        }
        
        return localVars
    }
    
    private static func collectTempVariables(_ function: SSAFunction, nameMap: SSAValueToCNameMap) -> [(any TypeProtocol, String)] {
        var tempVars: [(any TypeProtocol, String)] = []
        
        for block in function.blocks {
            for instruction in block.instructions {
                if let result = getInstructionResult(instruction) {
                    // Skip alloca results as they're handled as local vars
                    if !(instruction is AllocaInst) {
                        let varName = nameMap.getTempName(for: result)
                        tempVars.append((result.type, varName))
                    }
                }
            }
        }
        
        return tempVars
    }
    
    private static func lowerBasicBlock(_ block: BasicBlock, nameMap: SSAValueToCNameMap, isFirst: Bool) -> String {
        var output = ""
        
        // Generate block label (skip for first block)
        if !isFirst {
            output += "\(block.name):\n"
        }
        
        // Generate instructions
        for instruction in block.instructions {
            let ssaComment = formatInstructionComment(instruction)
            let cCode = lowerInstruction(instruction, nameMap: nameMap)
            output += "    // \(ssaComment)\n"
            output += "    \(cCode)\n"
        }
        
        // Generate terminator
        if let terminator = block.terminator {
            output += "    \(lowerTerminator(terminator, nameMap: nameMap))\n"
        }
        
        return output
    }
    
    private static func lowerInstruction(_ instruction: any SSAInstruction, nameMap: SSAValueToCNameMap) -> String {
        switch instruction {
        case let alloca as AllocaInst:
            // Alloca is handled by variable declaration, no runtime code needed
            return "// alloca \(formatCType(alloca.allocatedType))"
            
        case let load as LoadInst:
            let resultName = nameMap.getTempName(for: load.result!)
            let addressName = getValueName(load.address, nameMap: nameMap)
            return "\(resultName) = \(addressName);"
            
        case let store as StoreInst:
            let valueName = getValueName(store.value, nameMap: nameMap)
            let addressName = getValueName(store.address, nameMap: nameMap)
            return "\(addressName) = \(valueName);"
            
        case let binary as BinaryOp:
            let resultName = nameMap.getTempName(for: binary.result!)
            let leftName = getValueName(binary.left, nameMap: nameMap)
            let rightName = getValueName(binary.right, nameMap: nameMap)
            let op = formatBinaryOp(binary.operator)
            return "\(resultName) = \(leftName) \(op) \(rightName);"
            
        case let call as CallInst:
            let args = call.arguments.map { getValueName($0, nameMap: nameMap) }.joined(separator: ", ")
            if let result = call.result {
                let resultName = nameMap.getTempName(for: result)
                return "\(resultName) = \(call.function)(\(args));"
            } else {
                return "\(call.function)(\(args));"
            }
            
        case let cast as CastInst:
            let resultName = nameMap.getTempName(for: cast.result!)
            let valueName = getValueName(cast.value, nameMap: nameMap)
            let targetType = formatCType(cast.targetType)
            return "\(resultName) = (\(targetType))\(valueName);"
            
        default:
            return "// unknown instruction: \(type(of: instruction))"
        }
    }
    
    private static func lowerTerminator(_ terminator: any Terminator, nameMap: SSAValueToCNameMap) -> String {
        switch terminator {
        case let jump as JumpTerm:
            return "goto \(jump.target.name);"
            
        case let branch as BranchTerm:
            let condName = getValueName(branch.condition, nameMap: nameMap)
            return "if (\(condName)) goto \(branch.trueTarget.name); else goto \(branch.falseTarget.name);"
            
        case let ret as ReturnTerm:
            if let value = ret.value {
                let valueName = getValueName(value, nameMap: nameMap)
                return "return \(valueName);"
            } else {
                return "return;"
            }
            
        default:
            return "// unknown terminator: \(type(of: terminator))"
        }
    }
    
    private static func getValueName(_ value: any SSAValue, nameMap: SSAValueToCNameMap) -> String {
        switch value {
        case let constant as ConstantValue:
            return formatConstant(constant)
        case let result as InstructionResult:
            if result.instruction is AllocaInst {
                return nameMap.getLocalVarName(for: result)
            } else {
                return nameMap.getTempName(for: result)
            }
        case let param as BlockParameter:
            return nameMap.getTempName(for: param)
        default:
            return "unknown_value"
        }
    }
    
    private static func getInstructionResult(_ instruction: any SSAInstruction) -> InstructionResult? {
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
    
    private static func formatCType(_ type: any TypeProtocol) -> String {
        switch type {
        case is IntType:
            return "int64_t"
        case is Int8Type:
            return "char"
        case is Int32Type:
            return "int32_t"
        case is VoidType:
            return "void"
        case let pointer as PointerType:
            return "\(formatCType(pointer.pointee))*"
        default:
            return "void*" // fallback
        }
    }
    
    private static func formatBinaryOp(_ op: BinaryOp.Operator) -> String {
        switch op {
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "*"
        case .divide: return "/"
        case .modulo: return "%"
        }
    }
    
    private static func formatConstant(_ constant: ConstantValue) -> String {
        switch constant.value {
        case let intVal as Int:
            return "\(intVal)"
        case let floatVal as Float:
            return "\(floatVal)"
        case let doubleVal as Double:
            return "\(doubleVal)"
        case let boolVal as Bool:
            return boolVal ? "1" : "0"
        case let literal as LiteralValue:
            switch literal {
            case let .integer(str):
                return str
            case let .string(str):
                return "\"\(str)\""
            }
        default:
            // Debug: print what we got
            print("DEBUG: Unknown constant value type: \(type(of: constant.value)), value: \(constant.value)")
            return "0" // fallback
        }
    }
    
    private static func formatInstructionComment(_ instruction: any SSAInstruction) -> String {
        switch instruction {
        case let alloca as AllocaInst:
            let result = alloca.result != nil ? "%result" : "%unknown"
            return "\(result) = alloca $\(formatCType(alloca.allocatedType))"
            
        case let load as LoadInst:
            let result = load.result != nil ? "%result" : "%unknown"
            return "\(result) = load %address"
            
        case _ as StoreInst:
            return "store %value to %address"
            
        case let binary as BinaryOp:
            let result = binary.result != nil ? "%result" : "%unknown"
            let op = formatSSABinaryOp(binary.operator)
            return "\(result) = \(op) %left, %right"
            
        case let call as CallInst:
            if call.result != nil {
                return "%result = apply @\(call.function)(...)"
            } else {
                return "apply @\(call.function)(...)"
            }
            
        case let cast as CastInst:
            let result = cast.result != nil ? "%result" : "%unknown"
            return "\(result) = unconditional_checked_cast %value"
            
        default:
            return "unknown instruction: \(type(of: instruction))"
        }
    }
    
    private static func formatSSABinaryOp(_ op: BinaryOp.Operator) -> String {
        switch op {
        case .add: return "integer_add"
        case .subtract: return "integer_sub" 
        case .multiply: return "integer_mul"
        case .divide: return "integer_div"
        case .modulo: return "integer_mod"
        }
    }
}
