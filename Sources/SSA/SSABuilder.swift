import AST
import Types

/// Builds SSA form from typed AST
public final class SSABuilder {
    private var currentFunction: SSAFunction?
    private var currentBlock: BasicBlock?
    private var variableMap: [String: any SSAValue] = [:]
    private var blockCounter: Int = 0

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
        blockCounter = 0

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

        // If no explicit return, add appropriate return
        if currentBlock?.terminator == nil {
            if returnType is VoidType {
                currentBlock?.setTerminator(ReturnTerm())
            } else {
                // Add a default return for non-void functions (typically unreachable)
                let defaultValue = createDefaultValue(for: returnType)
                currentBlock?.setTerminator(ReturnTerm(value: defaultValue))
            }
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
        case let ifStmt as IfStatement:
            lowerIfStatement(ifStmt)
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
        case let intLiteral as IntegerLiteralExpression:
            return lowerIntegerLiteral(intLiteral)
        case let stringLiteral as StringLiteralExpression:
            return lowerStringLiteral(stringLiteral)
        case let boolLiteral as BooleanLiteralExpression:
            return lowerBooleanLiteral(boolLiteral)
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
        case .logicalAnd: op = .logicalAnd
        case .logicalOr: op = .logicalOr
        case .equal: op = .equal
        case .notEqual: op = .notEqual
        case .lessThan: op = .lessThan
        case .lessThanOrEqual: op = .lessThanOrEqual
        case .greaterThan: op = .greaterThan
        case .greaterThanOrEqual: op = .greaterThanOrEqual
        }

        let isComparisonOrLogical = op == .logicalAnd || op == .logicalOr ||
                                   op == .equal || op == .notEqual ||
                                   op == .lessThan || op == .lessThanOrEqual ||
                                   op == .greaterThan || op == .greaterThanOrEqual
        let resultType = binary.resolvedType ?? (isComparisonOrLogical ? BoolType() : IntType())
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
        let resultType = call.resolvedType ?? VoidType()

        // Check if this is actually a type cast (type constructor call)
        if isTypeCast(call) {
            // This is a type cast, not a function call
            guard call.arguments.count == 1 else {
                return ConstantValue(type: UnknownType(), value: "error")
            }

            let value = lowerExpression(call.arguments[0])
            let castInst = CastInst(value: value, targetType: resultType, result: nil)
            let result = InstructionResult(type: resultType, instruction: castInst)
            let castWithResult = CastInst(value: value, targetType: resultType, result: result)
            currentBlock.add(castWithResult)
            return result
        } else {
            // This is a regular function call
            let arguments = call.arguments.map { lowerExpression($0) }

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
    }

    /// Check if a call expression is actually a type cast
    private func isTypeCast(_ call: CallExpression) -> Bool {
        // A type cast is a call where:
        // 1. The function is a type name (Int32, Int, Bool, etc.)
        // 2. It has exactly one argument
        // 3. The resolved type matches the function name
        guard let identifierExpr = call.function as? IdentifierExpression,
              call.arguments.count == 1,
              let resultType = call.resolvedType
        else {
            return false
        }

        // Check if the function name corresponds to a built-in type
        let typeName = identifierExpr.name
        switch typeName {
        case "Int":
            return resultType is IntType
        case "Int8":
            return resultType is Int8Type
        case "Int32":
            return resultType is Int32Type
        case "Bool":
            return resultType is BoolType
        default:
            return false
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

    /// Lower an integer literal expression
    private func lowerIntegerLiteral(_ literal: IntegerLiteralExpression) -> any SSAValue {
        let type = literal.resolvedType ?? IntType()
        return ConstantValue(type: type, value: literal.value)
    }

    /// Lower a string literal expression
    private func lowerStringLiteral(_ literal: StringLiteralExpression) -> any SSAValue {
        let type = literal.resolvedType ?? PointerType(pointee: Int8Type())
        return ConstantValue(type: type, value: literal.value)
    }

    /// Lower a boolean literal expression
    private func lowerBooleanLiteral(_ literal: BooleanLiteralExpression) -> any SSAValue {
        let type = literal.resolvedType ?? BoolType()
        return ConstantValue(type: type, value: literal.value)
    }

    /// Lower an if statement to SSA with conditional branches
    private func lowerIfStatement(_ ifStmt: IfStatement) {
        guard let currentFunction = currentFunction else { return }
        
        // Create merge block that comes after all conditions
        let mergeBlock = currentFunction.createBlock(name: uniqueBlockName("merge"))
        
        // Start with the current block for the first condition
        var conditionBlock = currentBlock!
        
        for (index, clause) in ifStmt.clauses.enumerated() {
            // Evaluate condition in the condition block
            currentBlock = conditionBlock
            let condition = lowerExpression(clause.condition)
            
            // Create then block for this clause
            let thenBlock = currentFunction.createBlock(name: uniqueBlockName("then"))
            
            // Create block for next condition or else block
            let nextBlock: BasicBlock
            if index < ifStmt.clauses.count - 1 {
                // More clauses to check
                nextBlock = currentFunction.createBlock(name: uniqueBlockName("cond"))
            } else if ifStmt.elseBlock != nil {
                // Has else block
                nextBlock = currentFunction.createBlock(name: uniqueBlockName("else_block"))
            } else {
                // No more conditions, go to merge
                nextBlock = mergeBlock
            }
            
            // Add conditional branch to current condition block
            let branch = BranchTerm(
                condition: condition,
                trueTarget: thenBlock,
                falseTarget: nextBlock
            )
            conditionBlock.setTerminator(branch)
            
            // Lower the then block
            currentBlock = thenBlock
            lowerBlock(clause.block)
            
            // Jump to merge block if no terminator was set
            if currentBlock?.terminator == nil {
                currentBlock?.setTerminator(JumpTerm(target: mergeBlock))
            }
            
            // Move to next condition block (unless it's the merge block)
            if nextBlock !== mergeBlock {
                conditionBlock = nextBlock
            }
        }
        
        // Handle else block if present
        if let elseBlock = ifStmt.elseBlock {
            // The else block should be the last nextBlock we created
            let elseBlockBasic = ifStmt.clauses.isEmpty ? currentBlock! : conditionBlock
            currentBlock = elseBlockBasic
            lowerBlock(elseBlock)
            
            // Jump to merge block if no terminator was set
            if currentBlock?.terminator == nil {
                currentBlock?.setTerminator(JumpTerm(target: mergeBlock))
            }
        }
        
        // Continue with merge block
        currentBlock = mergeBlock
    }
    
    /// Create a default value for a given type (used for unreachable returns)
    private func createDefaultValue(for type: any TypeProtocol) -> any SSAValue {
        switch type {
        case is IntType, is Int8Type, is Int32Type:
            return ConstantValue(type: type, value: 0)
        case is BoolType:
            return ConstantValue(type: type, value: false)
        default:
            // For unknown types, return 0 as a fallback
            return ConstantValue(type: type, value: 0)
        }
    }
    
    /// Generate a unique block name using the counter
    private func uniqueBlockName(_ baseName: String) -> String {
        let name = "\(baseName)\(blockCounter)"
        blockCounter += 1
        return name
    }
}
