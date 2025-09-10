import Base
import AST
import Types

public final class SSAFunctionBuilder {
    private let function: FunctionDeclaration
    private let currentFunction: SSAFunction
    private var currentBlock: BasicBlock
    private var variableMap: [String: any SSAValue] = [:]
    private let selfStructType: StructType?
    private var selfParam: (any SSAValue)? = nil
    private let diagnostics: DiagnosticEngine

    init(function: FunctionDeclaration, methodOwner: StructType? = nil, nameOverride: String? = nil, diagnostics: DiagnosticEngine) {
        self.function = function

        // Extract parameter types
        var paramTypes: [any TypeProtocol] = []
        if let owner = methodOwner {
            paramTypes.append(PointerType(pointee: owner))
        }
        paramTypes += function.parameters.compactMap { $0.type.resolvedType }

        // Get return type
        let returnType = function.resolvedReturnType ?? VoidType()

        // Create SSA function
        let ssaFunc = SSAFunction(
            name: nameOverride ?? function.name,
            parameterTypes: paramTypes,
            returnType: returnType
        )

        self.currentFunction = ssaFunc
        self.currentBlock = ssaFunc.entryBlock
        self.selfStructType = methodOwner
        self.diagnostics = diagnostics
    }

    /// Lower a single function declaration to SSA
    public func lower() -> SSAFunction {
        // Map function parameters to block parameters
        var paramIndexOffset = 0
        if selfStructType != nil, !currentFunction.entryBlock.parameters.isEmpty {
            selfParam = currentFunction.entryBlock.parameters[0]
            paramIndexOffset = 1
        }
        for (index, param) in function.parameters.enumerated() {
            let idx = index + paramIndexOffset
            if idx < currentFunction.entryBlock.parameters.count {
                variableMap[param.name] = currentFunction.entryBlock.parameters[idx]
            }
        }

        // Unconditionally make allocas for all parameters (excluding implicit self)
        if !function.parameters.isEmpty {
            for (index, param) in function.parameters.enumerated() {
                let idx = index + paramIndexOffset
                guard idx < currentFunction.entryBlock.parameters.count else { continue }
                let incoming = currentFunction.entryBlock.parameters[idx]
                let pType: any TypeProtocol = param.type.resolvedType ?? UnknownType()
                let alloca = AllocaInst(allocatedType: pType, userProvidedName: param.name, result: nil)
                let allocaRes = InstructionResult(type: PointerType(pointee: pType), instruction: alloca)
                let allocaWithRes = AllocaInst(allocatedType: pType, userProvidedName: param.name, result: allocaRes)
                currentBlock.add(allocaWithRes)
                let store = StoreInst(address: allocaRes, value: incoming)
                currentBlock.add(store)
                variableMap[param.name] = allocaRes
            }
        }

        currentBlock = currentFunction.entryBlock

        // Lower function body
        if let body = function.body {
            lowerBlock(body)
        }

        // If no explicit return, add appropriate return
        if currentBlock.terminator == nil {
            if currentFunction.returnType is VoidType {
                currentBlock.setTerminator(ReturnTerm())
            } else {
                // Add a default return for non-void functions (typically unreachable)
                let defaultValue = createDefaultValue(for: currentFunction.returnType)
                currentBlock.setTerminator(ReturnTerm(value: defaultValue))
            }
        }

        // Clean up
        variableMap.removeAll()

        return currentFunction
    }

    // (no parametersNeedingAlloca; we always alloca parameters now)

    private func insert(_ instruction: any SSAInstruction) {
        currentBlock.add(instruction)
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
        case let mAssign as MemberAssignStatement:
            lowerMemberAssignStatement(mAssign)
        case let lvAssign as LValueAssignStatement:
            lowerLValueAssign(lvAssign)
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
        let originalBlock = currentBlock

        // If there's an initializer, use its type. Otherwise, use explicit type.
        let varType: any TypeProtocol
        if let initExpr = varBinding.value, let initType = initExpr.resolvedType {
            varType = initType
        } else if let t = varBinding.type?.resolvedType {
            varType = t
        } else {
            return
        }

        // Allocate memory for the variable in the original block
        let allocaInst = AllocaInst(allocatedType: varType, userProvidedName: varBinding.name, result: nil)
        let allocaResult = InstructionResult(type: PointerType(pointee: varType), instruction: allocaInst)
        let allocaWithResult = AllocaInst(allocatedType: varType, userProvidedName: varBinding.name, result: allocaResult)
        originalBlock.add(allocaWithResult)

        // If we have an initializer, store it
        if let initExpr = varBinding.value {
            let value = lowerExpression(initExpr)
            let storeInst = StoreInst(address: allocaResult, value: value)
            insert(storeInst)
        }

        // Map variable name to its alloca
        variableMap[varBinding.name] = allocaResult
    }

    /// Lower an assignment statement (x = expr)
    private func lowerAssignStatement(_ assignStmt: AssignStatement) {
        if let address = variableMap[assignStmt.name], address.type is PointerType {
            let value = lowerExpression(assignStmt.value)
            let storeInst = StoreInst(address: address, value: value)
            insert(storeInst)
            return
        }
        if let selfParam = selfParam, let structType = selfStructType,
           structType.fields.first(where: { $0.0 == assignStmt.name }) != nil {
            let fieldType = assignStmt.value.resolvedType ?? UnknownType()
            let addrInst = FieldAddressInst(baseAddress: selfParam, fieldPath: [assignStmt.name], result: nil)
            let addrRes = InstructionResult(type: PointerType(pointee: fieldType), instruction: addrInst)
            let addrWithRes = FieldAddressInst(baseAddress: selfParam, fieldPath: [assignStmt.name], result: addrRes)
            insert(addrWithRes)
            let value = lowerExpression(assignStmt.value)
            let storeInst = StoreInst(address: addrRes, value: value)
            insert(storeInst)
            return
        }
    }

    /// Lower a member assignment statement (p.x.y = value)
    private func lowerMemberAssignStatement(_ stmt: MemberAssignStatement) {
        guard let baseAddr = variableMap[stmt.baseName], baseAddr.type is PointerType else { return }
        // Compute the address of the nested field
        let fieldType = stmt.value.resolvedType ?? UnknownType()
        let addrInst = FieldAddressInst(baseAddress: baseAddr, fieldPath: stmt.memberPath, result: nil)
        let addrRes = InstructionResult(type: PointerType(pointee: fieldType), instruction: addrInst)
        let addrWithRes = FieldAddressInst(baseAddress: baseAddr, fieldPath: stmt.memberPath, result: addrRes)
        insert(addrWithRes)

        // Store the value
        let value = lowerExpression(stmt.value)
        let storeInst = StoreInst(address: addrRes, value: value)
        insert(storeInst)
    }

    /// Lower a general assignment with an arbitrary lvalue target
    private func lowerLValueAssign(_ stmt: LValueAssignStatement) {
        if let address = lowerAddress(of: stmt.target) {
            let value = lowerExpression(stmt.value)
            let storeInst = StoreInst(address: address, value: value)
            insert(storeInst)
        } else {
            let t = (stmt.target as any Expression).resolvedType ?? UnknownType()
            diagnostics.ssaCannotStore(at: stmt.range, type: t)
            _ = lowerExpression(stmt.value)
        }
    }

    /// Lower a return statement
    private func lowerReturnStatement(_ returnStmt: ReturnStatement) {
        let returnValue = returnStmt.value.map { lowerExpression($0) }
        let returnTerm = ReturnTerm(value: returnValue)

        currentBlock.setTerminator(returnTerm)
    }

    /// Lower an expression to SSA, returning the SSA value
    private func lowerExpression(_ expression: any Expression) -> any SSAValue {
        switch expression {
        case let binary as BinaryExpression:
            return lowerBinaryExpression(binary)
        case let unary as UnaryExpression:
            return lowerUnaryExpression(unary)
        case let call as CallExpression:
            return lowerCallExpression(call)
        case let cast as CastExpression:
            return lowerCastExpression(cast)
        case let member as MemberAccessExpression:
            return lowerMemberAccess(member)
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

    private func lowerMemberAccess(_ member: MemberAccessExpression) -> any SSAValue {
        // Flatten chained member access into a base and a path
        var path: [String] = []
        var baseExpr: any Expression = member
        while let mem = baseExpr as? MemberAccessExpression {
            path.insert(mem.member, at: 0)
            baseExpr = mem.base
        }

        // If base is an identifier referencing a local alloca, compute address via FieldAddressInst and load
        if let ident = baseExpr as? IdentifierExpression,
           let baseAddr = variableMap[ident.name],
           baseAddr.type is PointerType {
            // Determine final field type from the MemberAccessExpression's resolved type
            let fieldType = member.resolvedType ?? UnknownType()
            let addrInst = FieldAddressInst(baseAddress: baseAddr, fieldPath: path, result: nil)
            let addrRes = InstructionResult(type: PointerType(pointee: fieldType), instruction: addrInst)
            let addrWithRes = FieldAddressInst(baseAddress: baseAddr, fieldPath: path, result: addrRes)
            insert(addrWithRes)

            // Load from the computed address
            let loadInst = LoadInst(address: addrRes, result: nil)
            let loadRes = InstructionResult(type: fieldType, instruction: loadInst)
            let loadWithRes = LoadInst(address: addrRes, result: loadRes)
            insert(loadWithRes)
            return loadRes
        }

        // Fallback: evaluate base to a value and extract step by step
        var currentValue = lowerExpression(baseExpr)
        var currentType: any TypeProtocol = (baseExpr as? Expression)?.resolvedType ?? UnknownType()
        for name in path {
            let resultType: any TypeProtocol
            if let structType = currentType as? StructType, let field = structType.fields.first(where: { $0.0 == name }) {
                resultType = field.1
            } else {
                resultType = member.resolvedType ?? UnknownType()
            }
            let inst = FieldExtractInst(base: currentValue, fieldName: name, result: nil)
            let res = InstructionResult(type: resultType, instruction: inst)
            let withRes = FieldExtractInst(base: currentValue, fieldName: name, result: res)
            insert(withRes)
            currentValue = res
            currentType = resultType
        }
        return currentValue
    }

    /// Lower a unary expression
    private func lowerUnaryExpression(_ unary: UnaryExpression) -> any SSAValue {
        switch unary.operator {
        case .negate, .logicalNot:
            let operand = lowerExpression(unary.operand)
            let op: UnaryOp.Operator = (unary.operator == .negate) ? .negate : .logicalNot
            let resultType = unary.resolvedType ?? operand.type
            let unaryInst = UnaryOp(operator: op, operand: operand, result: nil)
            let result = InstructionResult(type: resultType, instruction: unaryInst)
            let unaryWithResult = UnaryOp(operator: op, operand: operand, result: result)
            insert(unaryWithResult)
            return result
        case .dereference:
            // Lower operand to an address and load from it
            let addressValue = lowerExpression(unary.operand)
            if !(addressValue.type is PointerType) {
                let t = (unary.operand as any Expression).resolvedType ?? addressValue.type
                diagnostics.ssaDereferenceNonPointer(at: unary.range, type: t)
                return ConstantValue(type: unary.resolvedType ?? UnknownType(), value: "error")
            }
            let resultType = unary.resolvedType ?? UnknownType()
            let loadInst = LoadInst(address: addressValue, result: nil)
            let result = InstructionResult(type: resultType, instruction: loadInst)
            let loadWithResult = LoadInst(address: addressValue, result: result)
            insert(loadWithResult)
            return result
        case .addressOf:
            // Compute address of lvalue operand
            if let addr = lowerAddress(of: unary.operand) {
                return addr
            } else {
                let t = (unary.operand as any Expression).resolvedType ?? UnknownType()
                diagnostics.ssaAddressOfNonLValue(at: unary.range, type: t)
                return ConstantValue(type: unary.resolvedType ?? UnknownType(), value: "error")
            }
        }
    }

    /// Compute the address of an lvalue expression, if possible
    private func lowerAddress(of expr: any Expression) -> (any SSAValue)? {
        // &identifier
        if let ident = expr as? IdentifierExpression {
            if let ssaValue = variableMap[ident.name] {
                // Only local variables (alloca) have addresses; block parameters do not
                if ssaValue is BlockParameter {
                    return nil
                }
                return ssaValue
            } else if let selfParam = selfParam, let structType = selfStructType,
                      structType.fields.first(where: { $0.0 == ident.name }) != nil {
                // &field inside method (implicit self)
                let fieldType = ident.resolvedType ?? UnknownType()
                let addrInst = FieldAddressInst(baseAddress: selfParam, fieldPath: [ident.name], result: nil)
                let addrRes = InstructionResult(type: PointerType(pointee: fieldType), instruction: addrInst)
                let addrWithRes = FieldAddressInst(baseAddress: selfParam, fieldPath: [ident.name], result: addrRes)
                insert(addrWithRes)
                return addrRes
            }
            return nil
        }

        // Address of member chain or plain member lvalue
        if let member = expr as? MemberAccessExpression {
            // Flatten path
            var path: [String] = []
            var baseExpr: any Expression = member
            while let mem = baseExpr as? MemberAccessExpression {
                path.insert(mem.member, at: 0)
                baseExpr = mem.base
            }

            if let baseIdent = baseExpr as? IdentifierExpression, let baseAddr = variableMap[baseIdent.name] {
                // Only if base is an alloca (not a parameter)
                if baseAddr is BlockParameter { return nil }
                let fieldType = member.resolvedType ?? UnknownType()
                let addrInst = FieldAddressInst(baseAddress: baseAddr, fieldPath: path, result: nil)
                let addrRes = InstructionResult(type: PointerType(pointee: fieldType), instruction: addrInst)
                let addrWithRes = FieldAddressInst(baseAddress: baseAddr, fieldPath: path, result: addrRes)
                insert(addrWithRes)
                return addrRes
            } else if let selfParam = selfParam, let _ = selfStructType {
                let fieldType = member.resolvedType ?? UnknownType()
                let addrInst = FieldAddressInst(baseAddress: selfParam, fieldPath: path, result: nil)
                let addrRes = InstructionResult(type: PointerType(pointee: fieldType), instruction: addrInst)
                let addrWithRes = FieldAddressInst(baseAddress: selfParam, fieldPath: path, result: addrRes)
                insert(addrWithRes)
                return addrRes
            }
        }

        // Address of dereference target: *p  => address is value of p
        if let un = expr as? UnaryExpression, un.operator == .dereference {
            let ptr = lowerExpression(un.operand)
            return ptr
        }

        return nil
    }

    /// Lower a binary expression
    private func lowerBinaryExpression(_ binary: BinaryExpression) -> any SSAValue {
        // Handle short-circuiting operators specially
        switch binary.operator {
        case .logicalAnd:
            return lowerShortCircuitAnd(binary)
        case .logicalOr:
            return lowerShortCircuitOr(binary)
        default:
            // Handle non-short-circuiting operators normally
            break
        }

        // For non-short-circuiting operators, evaluate both operands
        let left = lowerExpression(binary.left)
        let right = lowerExpression(binary.right)

        let op: BinaryOp.Operator
        switch binary.operator {
        case .add: op = .add
        case .subtract: op = .subtract
        case .multiply: op = .multiply
        case .divide: op = .divide
        case .modulo: op = .modulo
        case .equal: op = .equal
        case .notEqual: op = .notEqual
        case .lessThan: op = .lessThan
        case .lessThanOrEqual: op = .lessThanOrEqual
        case .greaterThan: op = .greaterThan
        case .greaterThanOrEqual: op = .greaterThanOrEqual
        default:
            // Should not reach here for logicalAnd/logicalOr
            return ConstantValue(type: UnknownType(), value: "error")
        }

        let isComparison = op == .equal || op == .notEqual ||
                          op == .lessThan || op == .lessThanOrEqual ||
                          op == .greaterThan || op == .greaterThanOrEqual
        let resultType = binary.resolvedType ?? (isComparison ? BoolType() : IntType())
        let binaryInst = BinaryOp(operator: op, left: left, right: right, result: nil)
        let result = InstructionResult(type: resultType, instruction: binaryInst)
        let binaryWithResult = BinaryOp(operator: op, left: left, right: right, result: result)
        insert(binaryWithResult)

        return result
    }

    /// Lower short-circuit operation (both && and ||)
    /// For &&: if left is false, return false, else evaluate right
    /// For ||: if left is true, return true, else evaluate right
    private func lowerShortCircuitOperation(_ binary: BinaryExpression, isAnd: Bool) -> any SSAValue {
        // Evaluate left operand in current block
        let left = lowerExpression(binary.left)

        // Create blocks for control flow
        let opName = isAnd ? "and" : "or"
        let continueBlock = currentFunction.createBlock(name: "\(opName)_continue")
        let mergeBlock = currentFunction.createBlock(name: "\(opName)_merge", parameterTypes: [BoolType()])

        // Create the short-circuit value and branch
        let shortCircuitValue = ConstantValue(type: BoolType(), value: !isAnd) // false for &&, true for ||
        let branch: BranchTerm

        if isAnd {
            // &&: if true go to right block, if false short-circuit with false
            branch = BranchTerm(condition: left,
                               trueTarget: continueBlock, trueArguments: [],
                               falseTarget: mergeBlock, falseArguments: [shortCircuitValue])
        } else {
            // ||: if true short-circuit with true, if false go to right block
            branch = BranchTerm(condition: left,
                               trueTarget: mergeBlock, trueArguments: [shortCircuitValue],
                               falseTarget: continueBlock, falseArguments: [])
        }

        currentBlock.setTerminator(branch)

        // Generate right operand evaluation starting in continueBlock.
        // The right expression may itself contain short-circuiting which
        // will set terminators and update currentBlock. Always add the
        // jump to merge from whatever block is current after lowering.
        self.currentBlock = continueBlock
        let right = lowerExpression(binary.right)

        if currentBlock.terminator == nil {
            let rightJump = JumpTerm(target: mergeBlock, arguments: [right])
            currentBlock.setTerminator(rightJump)
        }

        // Continue execution from the merge block
        self.currentBlock = mergeBlock

        // The result is the parameter of the merge block
        return mergeBlock.parameters[0]
    }

    /// Lower short-circuit AND operation: left && right
    private func lowerShortCircuitAnd(_ binary: BinaryExpression) -> any SSAValue {
        return lowerShortCircuitOperation(binary, isAnd: true)
    }

    /// Lower short-circuit OR operation: left || right
    private func lowerShortCircuitOr(_ binary: BinaryExpression) -> any SSAValue {
        return lowerShortCircuitOperation(binary, isAnd: false)
    }

    /// Lower a call expression
    private func lowerCallExpression(_ call: CallExpression) -> any SSAValue {
        // Method call: base.method(args) -> call Struct_method(selfPtr, args)
        if let member = call.function as? MemberAccessExpression {
            // Lower base to get its address if available
            if let baseIdent = member.base as? IdentifierExpression, let baseAddr = variableMap[baseIdent.name] {
                let baseType = member.base.resolvedType
                var funcName = "unknown"
                if let structType = baseType as? StructType {
                    funcName = "\(structType.name)_\(member.member)"
                }
                let args = [baseAddr] + call.arguments.map { lowerExpression($0.value) }
                let resultType = call.resolvedType ?? VoidType()
                if resultType is VoidType {
                    let callInst = CallInst(function: funcName, arguments: args, result: nil)
                    insert(callInst)
                    return ConstantValue(type: VoidType(), value: ())
                } else {
                    let callInst = CallInst(function: funcName, arguments: args, result: nil)
                    let result = InstructionResult(type: resultType, instruction: callInst)
                    let callWithResult = CallInst(function: funcName, arguments: args, result: result)
                    insert(callWithResult)
                    return result
                }
            }
        }

        let funcName = (call.function as? IdentifierExpression)?.name ?? "unknown"
        let resultType = call.resolvedType ?? VoidType()

        // Check if this is actually a type cast (type constructor call)
        if isTypeCast(call) {
            // This is a type cast, not a function call
            guard call.arguments.count == 1 else {
                return ConstantValue(type: UnknownType(), value: "error")
            }

            let value = lowerExpression(call.arguments[0].value)
            let castInst = CastInst(value: value, targetType: resultType, result: nil)
            let result = InstructionResult(type: resultType, instruction: castInst)
            let castWithResult = CastInst(value: value, targetType: resultType, result: result)
            insert(castWithResult)
            return result
        } else {
            // This is a regular function call
            let arguments = call.arguments.map { lowerExpression($0.value) }

            if resultType is VoidType {
                // Void function call
                let callInst = CallInst(function: funcName, arguments: arguments, result: nil)
                insert(callInst)
                return ConstantValue(type: VoidType(), value: ())
            } else {
                // Non-void function call
                let callInst = CallInst(function: funcName, arguments: arguments, result: nil)
                let result = InstructionResult(type: resultType, instruction: callInst)
                let callWithResult = CallInst(function: funcName, arguments: arguments, result: result)
                insert(callWithResult)
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
        let value = lowerExpression(cast.expression)
        let targetType = cast.resolvedType ?? IntType()

        let castInst = CastInst(value: value, targetType: targetType, result: nil)
        let result = InstructionResult(type: targetType, instruction: castInst)
        let castWithResult = CastInst(value: value, targetType: targetType, result: result)
        insert(castWithResult)

        return result
    }

    /// Lower an identifier expression (variable reference)
    private func lowerIdentifierExpression(_ identifier: IdentifierExpression) -> any SSAValue {
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
            insert(loadWithResult)
            return result
            }
        } else if let selfParam = selfParam, let structType = selfStructType,
                  structType.fields.first(where: { $0.0 == identifier.name }) != nil {
            // Implicit self field load
            let fieldType = identifier.resolvedType ?? UnknownType()
            let addrInst = FieldAddressInst(baseAddress: selfParam, fieldPath: [identifier.name], result: nil)
            let addrRes = InstructionResult(type: PointerType(pointee: fieldType), instruction: addrInst)
            let addrWithRes = FieldAddressInst(baseAddress: selfParam, fieldPath: [identifier.name], result: addrRes)
            insert(addrWithRes)
            let loadInst = LoadInst(address: addrRes, result: nil)
            let loadRes = InstructionResult(type: fieldType, instruction: loadInst)
            let loadWithRes = LoadInst(address: addrRes, result: loadRes)
            insert(loadWithRes)
            return loadRes
        } else {
            // Unknown identifier at lowering time; report and return error value
            diagnostics.ssaCannotComputeAddress(at: identifier.range, type: identifier.resolvedType ?? UnknownType())
            return ConstantValue(type: identifier.resolvedType ?? UnknownType(), value: "error")
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
        // Create merge block that comes after all conditions
        let mergeBlock = currentFunction.createBlock(name: "merge")

        for (index, clause) in ifStmt.clauses.enumerated() {
            // Evaluate condition in the current block. This may change currentBlock
            // (e.g., short-circuiting creates/finishes blocks and sets currentBlock
            // to a merge of its own). We must branch from whatever block is current
            // after lowering the condition value.
            let condition = lowerExpression(clause.condition)

            // Create then block for this clause
            let thenBlock = currentFunction.createBlock(name: "then")

            // Create block for next condition or else block
            let nextBlock: BasicBlock
            if index < ifStmt.clauses.count - 1 {
                // More clauses to check
                nextBlock = currentFunction.createBlock(name: "cond")
            } else if ifStmt.elseBlock != nil {
                // Has else block
                nextBlock = currentFunction.createBlock(name: "else_block")
            } else {
                // No more conditions, go to merge
                nextBlock = mergeBlock
            }

            // Add conditional branch to the current block (which is where the
            // condition value is available). Do NOT reference an earlier saved
            // block because short-circuiting may have already terminated it.
            let branch = BranchTerm(
                condition: condition,
                trueTarget: thenBlock,
                falseTarget: nextBlock
            )
            currentBlock.setTerminator(branch)

            // Lower the then block
            currentBlock = thenBlock
            lowerBlock(clause.block)

            // Jump to merge block if no terminator was set
            if currentBlock.terminator == nil {
                currentBlock.setTerminator(JumpTerm(target: mergeBlock))
            }

            // Continue with the next condition or else block
            currentBlock = nextBlock
        }

        // Handle else block if present
        if let elseBlock = ifStmt.elseBlock {
            // Lower the else block in the current block (which is the block
            // that represents the fallthrough from the last condition).
            lowerBlock(elseBlock)

            // Jump to merge block if no terminator was set
            if currentBlock.terminator == nil {
                currentBlock.setTerminator(JumpTerm(target: mergeBlock))
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
}

/// Builds SSA form from typed AST
public final class SSABuilder {
    private var currentFunction: SSAFunction?
    private var currentBlock: BasicBlock?
    public let diagnostics: DiagnosticEngine

    public init(diagnostics: DiagnosticEngine = DiagnosticEngine()) {
        self.diagnostics = diagnostics
    }

    /// Lower a list of declarations to SSA functions
    public func lower(declarations: [any Declaration]) -> [SSAFunction] {
        var functions: [SSAFunction] = []

        for declaration in declarations {
            if let funcDecl = declaration as? FunctionDeclaration, !funcDecl.isExtern {
                let functionBuilder = SSAFunctionBuilder(function: funcDecl, diagnostics: diagnostics)
                let ssaFunc = functionBuilder.lower()
                functions.append(ssaFunc)
            } else if let structDecl = declaration as? StructDeclaration {
                // Build owner struct type from fields (resolved types expected after type checking)
                var fieldTypes: [(String, any TypeProtocol)] = []
                for f in structDecl.fields {
                    let t = f.type?.resolvedType ?? UnknownType()
                    fieldTypes.append((f.name, t))
                }
                let ownerType = StructType(name: structDecl.name, fields: fieldTypes)
                for method in structDecl.methods {
                    let mangledName = "\(structDecl.name)_\(method.name)"
                    let functionBuilder = SSAFunctionBuilder(function: method, methodOwner: ownerType, nameOverride: mangledName, diagnostics: diagnostics)
                    let ssaFunc = functionBuilder.lower()
                    functions.append(ssaFunc)
                }
            }
        }

        return functions
    }
}
