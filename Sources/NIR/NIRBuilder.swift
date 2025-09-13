import AST
import Base
import Types

/// Walks an AST and builds an NIR representation that encodes the semantics of the program.
public final class NIRFunctionBuilder: ASTWalker {
    private let function: FunctionDeclaration
    private let currentFunction: NIRFunction
    private var currentBlock: BasicBlock
    private var variableMap: [String: any NIRValue] = [:]
    private let selfStructType: StructType?
    private var selfParam: (any NIRValue)?
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

        // Create NIR function
        let nirFunc = NIRFunction(
            name: nameOverride ?? function.name,
            parameterTypes: paramTypes,
            returnType: returnType
        )

        currentFunction = nirFunc
        currentBlock = nirFunc.entryBlock
        selfStructType = methodOwner
        self.diagnostics = diagnostics
    }

    /// Lower a single function declaration to NIR
    public func lower() -> NIRFunction {
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
                let alloca = AllocaInst(allocatedType: pType, userProvidedName: param.name)
                currentBlock.add(alloca)
                let store = StoreInst(address: alloca, value: incoming)
                currentBlock.add(store)
                variableMap[param.name] = alloca
            }
        }

        currentBlock = currentFunction.entryBlock

        // Lower function body via AST visitor
        if let body = function.body {
            _ = body.accept(self)
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

    private func insert(_ instruction: any NIRInstruction) {
        currentBlock.add(instruction)
    }

    /// Compute the address of an lvalue expression, if possible
    private func computeAddress(of expr: any Expression) -> (any NIRValue)? {
        if let ident = expr as? IdentifierExpression {
            if let ssaValue = variableMap[ident.name] {
                if ssaValue is BlockParameter { return nil }
                return ssaValue
            } else if let selfParam = selfParam, let structType = selfStructType,
                      structType.fields.first(where: { $0.0 == ident.name }) != nil
            {
                let fieldType = ident.resolvedType ?? UnknownType()
                let addrInst = FieldAddressInst(baseAddress: selfParam, fieldPath: [ident.name], type: PointerType(pointee: fieldType))
                insert(addrInst)
                return addrInst
            }
            return nil
        }

        if let member = expr as? MemberAccessExpression {
            var path: [String] = []
            var baseExpr: any Expression = member
            while let mem = baseExpr as? MemberAccessExpression {
                path.insert(mem.member, at: 0)
                baseExpr = mem.base
            }
            if let baseIdent = baseExpr as? IdentifierExpression, let baseAddr = variableMap[baseIdent.name] {
                if baseAddr is BlockParameter { return nil }
                let fieldType = member.resolvedType ?? UnknownType()
                let addrInst = FieldAddressInst(baseAddress: baseAddr, fieldPath: path, type: PointerType(pointee: fieldType))
                insert(addrInst)
                return addrInst
            } else if let selfParam = selfParam, let _ = selfStructType {
                let fieldType = member.resolvedType ?? UnknownType()
                let addrInst = FieldAddressInst(baseAddress: selfParam, fieldPath: path, type: PointerType(pointee: fieldType))
                insert(addrInst)
                return addrInst
            }
        }

        if let un = expr as? UnaryExpression, un.operator == .dereference {
            let ptr = un.operand.accept(self) ?? Undef()
            return ptr
        }

        return nil
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

    /// Lower an identifier expression (variable reference)
    private func materializeIdentifier(_ identifier: IdentifierExpression) -> any NIRValue {
        // Check if it's in our variable map
        if let ssaValue = variableMap[identifier.name] {
            // If it's a function parameter (BlockParameter), use it directly
            if ssaValue is BlockParameter {
                return ssaValue
            }
            // If it's a local variable (alloca result), load from it
            else {
                let resultType = identifier.resolvedType ?? IntType()
                let loadInst = LoadInst(address: ssaValue, type: resultType)
                insert(loadInst)
                return loadInst
            }
        } else if let selfParam = selfParam, let structType = selfStructType,
                  structType.fields.first(where: { $0.0 == identifier.name }) != nil
        {
            // Implicit self field load
            let fieldType = identifier.resolvedType ?? UnknownType()
            let addrInst = FieldAddressInst(baseAddress: selfParam, fieldPath: [identifier.name], type: PointerType(pointee: fieldType))
            insert(addrInst)
            let loadInst = LoadInst(address: addrInst, type: fieldType)
            insert(loadInst)
            return loadInst
        } else {
            // Unknown identifier at lowering time; report and return error value
            diagnostics.nirCannotComputeAddress(at: identifier.range, type: identifier.resolvedType ?? UnknownType())
            return Constant(type: identifier.resolvedType ?? UnknownType(), value: "error")
        }
    }

    /// Create a default value for a given type (used for unreachable returns)
    private func createDefaultValue(for type: any TypeProtocol) -> any NIRValue {
        switch type {
        case is IntType, is Int8Type, is Int32Type:
            return Constant(type: type, value: 0)
        case is BoolType:
            return Constant(type: type, value: false)
        default:
            // For unknown types, return 0 as a fallback
            return Constant(type: type, value: 0)
        }
    }

    public typealias Result = (any NIRValue)?

    // Declarations (ignored in this context)
    public func visit(_: FunctionDeclaration) -> Result { nil }
    public func visit(_: ExternDeclaration) -> Result { nil }
    public func visit(_: StructDeclaration) -> Result { nil }

    // Types (ignored in NIR lowering)
    public func visit(_: NominalTypeNode) -> Result { nil }
    public func visit(_: PointerTypeNode) -> Result { nil }
    public func visit(_: EllipsisTypeNode) -> Result { nil }

    // Statements (perform effects; return nil)
    public func visit(_ node: VarBinding) -> Result {
        let originalBlock = currentBlock
        // Determine variable type from initializer or explicit type
        let varType: any TypeProtocol
        if let initExpr = node.value, let initType = initExpr.resolvedType {
            varType = initType
        } else if let t = node.type?.resolvedType {
            varType = t
        } else {
            return nil
        }
        // Allocate and optionally initialize
        let allocaInst = AllocaInst(allocatedType: varType, userProvidedName: node.name)
        originalBlock.add(allocaInst)
        if let initExpr = node.value {
            let value = initExpr.accept(self) ?? Undef()
            insert(StoreInst(address: allocaInst, value: value))
        }
        variableMap[node.name] = allocaInst
        return nil
    }

    public func visit(_ node: AssignStatement) -> Result {
        if let address = variableMap[node.name], address.type is PointerType {
            let value = node.value.accept(self) ?? Undef()
            insert(StoreInst(address: address, value: value))
            return nil
        }
        if let selfParam = selfParam, let structType = selfStructType,
           structType.fields.first(where: { $0.0 == node.name }) != nil
        {
            let fieldType = node.value.resolvedType ?? UnknownType()
            let addrInst = FieldAddressInst(baseAddress: selfParam, fieldPath: [node.name], type: PointerType(pointee: fieldType))
            insert(addrInst)
            let value = node.value.accept(self) ?? Undef()
            insert(StoreInst(address: addrInst, value: value))
            return nil
        }
        return nil
    }

    public func visit(_ node: MemberAssignStatement) -> Result {
        guard let baseAddr = variableMap[node.baseName], baseAddr.type is PointerType else { return nil }
        let fieldType = node.value.resolvedType ?? UnknownType()
        let addrInst = FieldAddressInst(baseAddress: baseAddr, fieldPath: node.memberPath, type: PointerType(pointee: fieldType))
        insert(addrInst)
        let value = node.value.accept(self) ?? Undef()
        insert(StoreInst(address: addrInst, value: value))
        return nil
    }

    public func visit(_ node: LValueAssignStatement) -> Result {
        if let address = computeAddress(of: node.target) {
            let value = node.value.accept(self) ?? Undef()
            insert(StoreInst(address: address, value: value))
        } else {
            let t = (node.target as any Expression).resolvedType ?? UnknownType()
            diagnostics.nirCannotStore(at: node.range, type: t)
            _ = node.value.accept(self)
        }
        return nil
    }

    public func visit(_ node: ReturnStatement) -> Result {
        let returnValue = node.value.map { $0.accept(self) ?? Undef() }
        currentBlock.setTerminator(ReturnTerm(value: returnValue))
        return nil
    }

    public func visit(_ node: Block) -> Result {
        for statement in node.statements {
            _ = statement.accept(self)
        }
        return nil
    }

    public func visit(_ node: ExpressionStatement) -> Result {
        _ = node.expression.accept(self)
        return nil
    }

    public func visit(_ node: IfStatement) -> Result {
        let mergeBlock = currentFunction.createBlock(name: "merge")
        for (index, clause) in node.clauses.enumerated() {
            let condition = clause.condition.accept(self) ?? Constant(type: BoolType(), value: false)
            let thenBlock = currentFunction.createBlock(name: "then")
            let nextBlock: BasicBlock
            if index < node.clauses.count - 1 {
                nextBlock = currentFunction.createBlock(name: "cond")
            } else if node.elseBlock != nil {
                nextBlock = currentFunction.createBlock(name: "else_block")
            } else {
                nextBlock = mergeBlock
            }
            let branch = BranchTerm(
                condition: condition,
                trueTarget: thenBlock,
                falseTarget: nextBlock
            )
            currentBlock.setTerminator(branch)

            currentBlock = thenBlock
            for stmt in clause.block.statements {
                _ = stmt.accept(self)
            }
            if currentBlock.terminator == nil {
                currentBlock.setTerminator(JumpTerm(target: mergeBlock))
            }
            currentBlock = nextBlock
        }
        if let elseBlock = node.elseBlock {
            for stmt in elseBlock.statements {
                _ = stmt.accept(self)
            }
            if currentBlock.terminator == nil {
                currentBlock.setTerminator(JumpTerm(target: mergeBlock))
            }
        }
        currentBlock = mergeBlock
        return nil
    }

    // Expressions (lower and return produced value)
    public func visit(_ node: BinaryExpression) -> Result {
        switch node.operator {
        case .logicalAnd, .logicalOr:
            let isAnd = (node.operator == .logicalAnd)
            let left = node.left.accept(self) ?? Constant(type: BoolType(), value: false)
            let opName = isAnd ? "and" : "or"
            let continueBlock = currentFunction.createBlock(name: "\(opName)_continue")
            let mergeBlock = currentFunction.createBlock(name: "\(opName)_merge", parameterTypes: [BoolType()])
            let shortCircuitValue = Constant(type: BoolType(), value: !isAnd)
            let branch: BranchTerm
            if isAnd {
                branch = BranchTerm(condition: left,
                                    trueTarget: continueBlock, trueArguments: [],
                                    falseTarget: mergeBlock, falseArguments: [shortCircuitValue])
            } else {
                branch = BranchTerm(condition: left,
                                    trueTarget: mergeBlock, trueArguments: [shortCircuitValue],
                                    falseTarget: continueBlock, falseArguments: [])
            }
            currentBlock.setTerminator(branch)
            currentBlock = continueBlock
            let right = node.right.accept(self) ?? Constant(type: BoolType(), value: false)
            if currentBlock.terminator == nil {
                currentBlock.setTerminator(JumpTerm(target: mergeBlock, arguments: [right]))
            }
            currentBlock = mergeBlock
            return mergeBlock.parameters[0]
        default:
            let left = node.left.accept(self) ?? Undef()
            let right = node.right.accept(self) ?? Undef()
            let op: BinaryOp.Operator
            switch node.operator {
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
                return Undef()
            }
            let isComparison = op == .equal || op == .notEqual ||
                op == .lessThan || op == .lessThanOrEqual ||
                op == .greaterThan || op == .greaterThanOrEqual
            let resultType = node.resolvedType ?? (isComparison ? BoolType() : IntType())
            let binaryInst = BinaryOp(operator: op, left: left, right: right, type: resultType)
            insert(binaryInst)
            return binaryInst
        }
    }

    public func visit(_ node: UnaryExpression) -> Result {
        switch node.operator {
        case .negate, .logicalNot:
            let operand = node.operand.accept(self) ?? Undef()
            let op: UnaryOp.Operator = (node.operator == .negate) ? .negate : .logicalNot
            let resultType = node.resolvedType ?? operand.type
            let unaryInst = UnaryOp(operator: op, operand: operand, type: resultType)
            insert(unaryInst)
            return unaryInst
        case .dereference:
            let addressValue = node.operand.accept(self) ?? Undef()
            if !(addressValue.type is PointerType) {
                let t = (node.operand as any Expression).resolvedType ?? addressValue.type
                diagnostics.nirDereferenceNonPointer(at: node.range, type: t)
                return Constant(type: node.resolvedType ?? UnknownType(), value: "error")
            }
            let resultType = node.resolvedType ?? UnknownType()
            let loadInst = LoadInst(address: addressValue, type: resultType)
            insert(loadInst)
            return loadInst
        case .addressOf:
            if let addr = computeAddress(of: node.operand) {
                return addr
            } else {
                let t = (node.operand as any Expression).resolvedType ?? UnknownType()
                diagnostics.nirAddressOfNonLValue(at: node.range, type: t)
                return Constant(type: node.resolvedType ?? UnknownType(), value: "error")
            }
        }
    }

    public func visit(_ node: CallExpression) -> Result {
        if let member = node.function as? MemberAccessExpression {
            if let baseIdent = member.base as? IdentifierExpression, let baseAddr = variableMap[baseIdent.name] {
                let baseType = member.base.resolvedType
                var funcName = "unknown"
                if let structType = baseType as? StructType {
                    funcName = "\(structType.name)_\(member.member)"
                }
                let args: [any NIRValue] = [baseAddr] + node.arguments.map { $0.value.accept(self) ?? Undef() }
                let resultType = node.resolvedType ?? VoidType()
                if resultType is VoidType {
                    let callInst = CallInst(function: funcName, arguments: args, type: VoidType())
                    insert(callInst)
                    return Constant(type: VoidType())
                } else {
                    let callInst = CallInst(function: funcName, arguments: args, type: resultType)
                    insert(callInst)
                    return callInst
                }
            }
        }
        let funcName = (node.function as? IdentifierExpression)?.name ?? "unknown"
        let resultType = node.resolvedType ?? VoidType()
        if isTypeCast(node) {
            guard node.arguments.count == 1 else {
                return Undef()
            }
            let value = node.arguments[0].value.accept(self) ?? Undef()
            let castInst = CastInst(value: value, targetType: resultType)
            insert(castInst)
            return castInst
        } else {
            let arguments = node.arguments.map { $0.value.accept(self) ?? Undef() }
            if resultType is VoidType {
                let callInst = CallInst(function: funcName, arguments: arguments, type: VoidType())
                insert(callInst)
                return Constant(type: VoidType())
            } else {
                let callInst = CallInst(function: funcName, arguments: arguments, type: resultType)
                insert(callInst)
                return callInst
            }
        }
    }

    public func visit(_ node: CastExpression) -> Result {
        let value = node.expression.accept(self) ?? Undef()
        let targetType = node.resolvedType ?? IntType()
        let castInst = CastInst(value: value, targetType: targetType)
        insert(castInst)
        return castInst
    }

    public func visit(_ node: MemberAccessExpression) -> Result {
        var path: [String] = []
        var baseExpr: any Expression = node
        while let mem = baseExpr as? MemberAccessExpression {
            path.insert(mem.member, at: 0)
            baseExpr = mem.base
        }
        if let ident = baseExpr as? IdentifierExpression,
           let baseAddr = variableMap[ident.name],
           baseAddr.type is PointerType
        {
            let fieldType = node.resolvedType ?? UnknownType()
            let addrInst = FieldAddressInst(baseAddress: baseAddr, fieldPath: path, type: PointerType(pointee: fieldType))
            insert(addrInst)
            let loadInst = LoadInst(address: addrInst, type: fieldType)
            insert(loadInst)
            return loadInst
        }
        var currentValue = baseExpr.accept(self) ?? Undef()
        var currentType: any TypeProtocol = baseExpr.resolvedType ?? UnknownType()
        for name in path {
            let resultType: any TypeProtocol
            if let structType = currentType as? StructType, let field = structType.fields.first(where: { $0.0 == name }) {
                resultType = field.1
            } else {
                resultType = node.resolvedType ?? UnknownType()
            }
            let inst = FieldExtractInst(base: currentValue, fieldName: name, type: resultType)
            insert(inst)
            currentValue = inst
            currentType = resultType
        }
        return currentValue
    }

    public func visit(_ node: IdentifierExpression) -> Result {
        return materializeIdentifier(node)
    }

    public func visit(_ node: IntegerLiteralExpression) -> Result {
        let type = node.resolvedType ?? IntType()
        return Constant(type: type, value: Int(node.value) ?? 0)
    }

    public func visit(_ node: StringLiteralExpression) -> Result {
        let type = node.resolvedType ?? PointerType(pointee: Int8Type())
        return Constant(type: type, value: node.value)
    }

    public func visit(_ node: BooleanLiteralExpression) -> Result {
        let type = node.resolvedType ?? BoolType()
        return Constant(type: type, value: node.value)
    }

    // Parameters (ignored)
    public func visit(_: Parameter) -> Result { nil }
}

/// Builds SSA form from typed AST
public final class NIRBuilder {
    private var currentFunction: NIRFunction?
    private var currentBlock: BasicBlock?
    public let diagnostics: DiagnosticEngine

    public init(diagnostics: DiagnosticEngine = DiagnosticEngine()) {
        self.diagnostics = diagnostics
    }

    /// Lower a list of declarations to NIR functions
    public func lower(declarations: [any Declaration]) -> [NIRFunction] {
        var functions: [NIRFunction] = []

        for declaration in declarations {
            if let funcDecl = declaration as? FunctionDeclaration, !funcDecl.isExtern {
                let functionBuilder = NIRFunctionBuilder(function: funcDecl, diagnostics: diagnostics)
                let nirFunc = functionBuilder.lower()
                functions.append(nirFunc)
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
                    let functionBuilder = NIRFunctionBuilder(function: method, methodOwner: ownerType, nameOverride: mangledName, diagnostics: diagnostics)
                    let nirFunc = functionBuilder.lower()
                    functions.append(nirFunc)
                }
            }
        }

        return functions
    }
}
