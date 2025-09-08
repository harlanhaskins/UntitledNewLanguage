import AST
import Types

/// Builds SSA form from typed AST
public final class SSABuilder {
    private var currentFunction: SSAFunction?
    private var currentBlock: BasicBlock?
    private var variableMap: [String: any SSAValue] = [:]
    
    public init() {}
    
    /// Lower a list of declarations to SSA functions
    public func lower(declarations: [any Declaration]) -> [SSAFunction] {
        var functions: [SSAFunction] = []
        
        for declaration in declarations {
            if let funcDecl = declaration as? FunctionDeclaration, !funcDecl.isExtern {
                let ssaFunc = lowerFunction(funcDecl)
                functions.append(ssaFunc)
            }
        }
        
        return functions
    }
    
    /// Lower a single function declaration to SSA
    private func lowerFunction(_ funcDecl: FunctionDeclaration) -> SSAFunction {
        // Extract parameter types
        let paramTypes = funcDecl.parameters.compactMap { param in
            param.type.resolvedType
        }
        
        // Get return type
        let returnType = funcDecl.resolvedReturnType ?? VoidType()
        
        // Create SSA function
        let ssaFunc = SSAFunction(
            name: funcDecl.name,
            parameterTypes: paramTypes,
            returnType: returnType
        )
        
        currentFunction = ssaFunc
        
        // Create entry block with parameters
        let entry = ssaFunc.createBlock(name: "entry", parameterTypes: paramTypes)
        
        // Map function parameters to block parameters
        for (index, param) in funcDecl.parameters.enumerated() {
            if index < entry.parameters.count {
                variableMap[param.name] = entry.parameters[index]
            }
        }
        
        currentBlock = entry
        
        // Lower function body
        if let body = funcDecl.body {
            lowerBlock(body)
        }
        
        // If no explicit return, add void return
        if currentBlock?.terminator == nil {
            currentBlock?.setTerminator(ReturnTerm())
        }
        
        // Clean up
        currentFunction = nil
        currentBlock = nil
        variableMap.removeAll()
        
        return ssaFunc
    }
    
    /// Lower a block statement
    private func lowerBlock(_ block: Block) {
        for statement in block.statements {
            lowerStatement(statement)
        }
    }
    
    /// Lower a statement to SSA
    private func lowerStatement(_ statement: any Statement) {
        switch statement {
        case let varBinding as VarBinding:
            lowerVarBinding(varBinding)
        case let assignStmt as AssignStatement:
            lowerAssignStatement(assignStmt)
        case let returnStmt as ReturnStatement:
            lowerReturnStatement(returnStmt)
        case let exprStmt as ExpressionStatement:
            _ = lowerExpression(exprStmt.expression)
        case let nestedBlock as Block:
            lowerBlock(nestedBlock)
        default:
            // TODO: Handle other statement types
            break
        }
    }
    
    /// Lower a variable binding (var x = expr)
    private func lowerVarBinding(_ varBinding: VarBinding) {
        guard let currentBlock = currentBlock else { return }
        
        // Get the variable type from the expression
        guard let varType = varBinding.value.resolvedType else { return }
        
        // Allocate memory for the variable
        let allocaInst = AllocaInst(allocatedType: varType, result: nil)
        let allocaResult = InstructionResult(type: PointerType(pointee: varType), instruction: allocaInst)
        let allocaWithResult = AllocaInst(allocatedType: varType, result: allocaResult)
        currentBlock.add(allocaWithResult)
        
        // Store the initial value
        let value = lowerExpression(varBinding.value)
        let storeInst = StoreInst(address: allocaResult, value: value)
        currentBlock.add(storeInst)
        
        // Map variable name to its alloca
        variableMap[varBinding.name] = allocaResult
    }
    
    /// Lower an assignment statement (x = expr)
    private func lowerAssignStatement(_ assignStmt: AssignStatement) {
        guard let currentBlock = currentBlock else { return }
        guard let address = variableMap[assignStmt.name] else { return }
        
        let value = lowerExpression(assignStmt.value)
        let storeInst = StoreInst(address: address, value: value)
        currentBlock.add(storeInst)
    }
    
    /// Lower a return statement
    private func lowerReturnStatement(_ returnStmt: ReturnStatement) {
        guard let currentBlock = currentBlock else { return }
        
        let returnValue = returnStmt.value.map { lowerExpression($0) }
        let returnTerm = ReturnTerm(value: returnValue)
        currentBlock.setTerminator(returnTerm)
    }
    
    /// Lower an expression to SSA, returning the SSA value
    private func lowerExpression(_ expression: any Expression) -> any SSAValue {
        switch expression {
        case let binary as BinaryExpression:
            return lowerBinaryExpression(binary)
        case let call as CallExpression:
            return lowerCallExpression(call)
        case let cast as CastExpression:
            return lowerCastExpression(cast)
        case let identifier as IdentifierExpression:
            return lowerIdentifierExpression(identifier)
        case let literal as LiteralExpression:
            return lowerLiteralExpression(literal)
        default:
            // Fallback - create unknown constant
            return ConstantValue(type: UnknownType(), value: "unknown")
        }
    }
    
    /// Lower a binary expression
    private func lowerBinaryExpression(_ binary: BinaryExpression) -> any SSAValue {
        guard let currentBlock = currentBlock else {
            return ConstantValue(type: UnknownType(), value: "error")
        }
        
        let left = lowerExpression(binary.left)
        let right = lowerExpression(binary.right)
        
        let op: BinaryOp.Operator
        switch binary.operator {
        case .add: op = .add
        case .subtract: op = .subtract
        case .multiply: op = .multiply
        case .divide: op = .divide
        case .modulo: op = .modulo
        }
        
        let resultType = binary.resolvedType ?? IntType()
        let binaryInst = BinaryOp(operator: op, left: left, right: right, result: nil)
        let result = InstructionResult(type: resultType, instruction: binaryInst)
        let binaryWithResult = BinaryOp(operator: op, left: left, right: right, result: result)
        currentBlock.add(binaryWithResult)
        
        return result
    }
    
    /// Lower a call expression
    private func lowerCallExpression(_ call: CallExpression) -> any SSAValue {
        guard let currentBlock = currentBlock else {
            return ConstantValue(type: UnknownType(), value: "error")
        }
        
        let funcName = (call.function as? IdentifierExpression)?.name ?? "unknown"
        let arguments = call.arguments.map { lowerExpression($0) }
        
        let resultType = call.resolvedType ?? VoidType()
        
        if resultType is VoidType {
            // Void function call
            let callInst = CallInst(function: funcName, arguments: arguments, result: nil)
            currentBlock.add(callInst)
            return ConstantValue(type: VoidType(), value: ())
        } else {
            // Non-void function call
            let callInst = CallInst(function: funcName, arguments: arguments, result: nil)
            let result = InstructionResult(type: resultType, instruction: callInst)
            let callWithResult = CallInst(function: funcName, arguments: arguments, result: result)
            currentBlock.add(callWithResult)
            return result
        }
    }
    
    /// Lower a cast expression
    private func lowerCastExpression(_ cast: CastExpression) -> any SSAValue {
        guard let currentBlock = currentBlock else {
            return ConstantValue(type: UnknownType(), value: "error")
        }
        
        let value = lowerExpression(cast.expression)
        let targetType = cast.resolvedType ?? IntType()
        
        let castInst = CastInst(value: value, targetType: targetType, result: nil)
        let result = InstructionResult(type: targetType, instruction: castInst)
        let castWithResult = CastInst(value: value, targetType: targetType, result: result)
        currentBlock.add(castWithResult)
        
        return result
    }
    
    /// Lower an identifier expression (variable reference)
    private func lowerIdentifierExpression(_ identifier: IdentifierExpression) -> any SSAValue {
        guard let currentBlock = currentBlock else {
            return ConstantValue(type: UnknownType(), value: "error")
        }
        
        // Check if it's in our variable map
        if let ssaValue = variableMap[identifier.name] {
            // If it's a function parameter (BlockParameter), use it directly
            if ssaValue is BlockParameter {
                return ssaValue
            }
            // If it's a local variable (alloca result), load from it
            else {
                let loadInst = LoadInst(address: ssaValue, result: nil)
                let resultType = identifier.resolvedType ?? IntType()
                let result = InstructionResult(type: resultType, instruction: loadInst)
                let loadWithResult = LoadInst(address: ssaValue, result: result)
                currentBlock.add(loadWithResult)
                return result
            }
        } else {
            // Fallback for unknown identifiers
            return ConstantValue(type: identifier.resolvedType ?? IntType(), value: identifier.name)
        }
    }
    
    /// Lower a literal expression
    private func lowerLiteralExpression(_ literal: LiteralExpression) -> any SSAValue {
        let type = literal.resolvedType ?? IntType()
        return ConstantValue(type: type, value: literal.value)
    }
}
