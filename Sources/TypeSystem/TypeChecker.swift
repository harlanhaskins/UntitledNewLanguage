import AST
import Base
import Types

/// Environment for type checking - tracks variables and their types
public final class TypeEnvironment {
    private var scopes: [String: any TypeProtocol] = [:]
    private var parent: TypeEnvironment?

    public init(parent: TypeEnvironment? = nil) {
        self.parent = parent
    }

    public func define(_ name: String, type: any TypeProtocol) {
        scopes[name] = type
    }

    public func lookup(_ name: String) -> (any TypeProtocol)? {
        if let type = scopes[name] {
            return type
        }
        return parent?.lookup(name)
    }

    public func pushScope() -> TypeEnvironment {
        return TypeEnvironment(parent: self)
    }
}

/// Type checker that walks the AST and performs type checking
public final class TypeChecker: ASTWalker {
    public typealias Result = any TypeProtocol

    private var environment: TypeEnvironment
    private let diagnostics: DiagnosticEngine
    private var currentStructContext: StructType? = nil
    private var functionDeclsByName: [String: FunctionDeclaration] = [:]
    private var structDeclsByName: [String: StructDeclaration] = [:]

    public init(diagnostics: DiagnosticEngine = DiagnosticEngine()) {
        environment = TypeEnvironment()
        self.diagnostics = diagnostics
        setupBuiltinTypes()
    }

    private func setupBuiltinTypes() {
        // Built-in type constructors (for casts like Int32(x))
        environment.define("Int", type: IntType())
        environment.define("Int8", type: Int8Type())
        environment.define("Int32", type: Int32Type())
    }

    public func typeCheck(declarations: [any Declaration]) {
        // First pass: collect struct and function signatures
        for declaration in declarations {
            if let structDecl = declaration as? StructDeclaration {
                // Predeclare struct types so they can be referenced
                let baseStructType = buildStructType(from: structDecl)
                structDeclsByName[structDecl.name] = structDecl
                // Build method types (with implicit self) and attach to struct type
                var methodMap: [String: FunctionType] = [:]
                for method in structDecl.methods {
                    let mt = buildMethodType(from: method, owner: baseStructType)
                    methodMap[method.name] = mt
                }
                let fullStructType = StructType(name: baseStructType.name, fields: baseStructType.fields, methods: methodMap)
                environment.define(structDecl.name, type: fullStructType)
            } else if let funcDecl = declaration as? FunctionDeclaration {
                let funcType = buildFunctionType(from: funcDecl)
                functionDeclsByName[funcDecl.name] = funcDecl
                environment.define(funcDecl.name, type: funcType)
            } else if let externDecl = declaration as? ExternDeclaration {
                let funcType = buildFunctionType(from: externDecl.function)
                functionDeclsByName[externDecl.function.name] = externDecl.function
                environment.define(externDecl.function.name, type: funcType)
            }
        }

        // Second pass: type check function bodies
        for declaration in declarations {
            _ = declaration.accept(self)
        }
    }

    // MARK: - Pretty operator symbols
    private func symbol(_ op: BinaryOperator) -> String {
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

    private func symbol(_ op: UnaryOperator) -> String {
        switch op {
        case .negate: return "-"
        case .logicalNot: return "!"
        case .addressOf: return "&"
        case .dereference: return "*"
        }
    }

    private func buildStructType(from structDecl: StructDeclaration) -> StructType {
        var fieldTypes: [(String, any TypeProtocol)] = []
        for field in structDecl.fields {
            if let fieldTypeNode = field.type {
                let ft = fieldTypeNode.accept(self)
                fieldTypes.append((field.name, ft))
            } else {
                diagnostics.missingFieldType(at: field.range, name: field.name)
                fieldTypes.append((field.name, UnknownType()))
            }
        }
        return StructType(name: structDecl.name, fields: fieldTypes)
    }

    private func buildFunctionType(from funcDecl: FunctionDeclaration) -> FunctionType {
        var paramTypes: [any TypeProtocol] = []
        var isVariadic = false
        var labels: [String?] = []

        for param in funcDecl.parameters {
            // Use resolved type if available, otherwise resolve it
            let paramType = param.type.resolvedType ?? param.type.accept(self)
            param.type.resolvedType = paramType
            paramTypes.append(paramType)
            labels.append(param.label)
            if param.isVariadic {
                isVariadic = true
            }
        }

        let returnType: any TypeProtocol = funcDecl.resolvedReturnType ?? funcDecl.returnType?.accept(self) ?? VoidType()

        return FunctionType(parameters: paramTypes, returnType: returnType, isVariadic: isVariadic, labels: labels)
    }

    private func buildMethodType(from funcDecl: FunctionDeclaration, owner: StructType) -> FunctionType {
        var paramTypes: [any TypeProtocol] = [owner]
        var isVariadic = false
        var labels: [String?] = [nil] // implicit self has no external label
        for param in funcDecl.parameters {
            let p = param.type.resolvedType ?? param.type.accept(self)
            param.type.resolvedType = p
            paramTypes.append(p)
            labels.append(param.label)
            if param.isVariadic { isVariadic = true }
        }
        let returnType: any TypeProtocol = funcDecl.resolvedReturnType ?? funcDecl.returnType?.accept(self) ?? VoidType()
        return FunctionType(parameters: paramTypes, returnType: returnType, isVariadic: isVariadic, labels: labels)
    }

    // Diagnostic reporting is now handled directly through the diagnostics engine

    // MARK: - ASTWalker Implementation

    public func visit(_ node: FunctionDeclaration) -> any TypeProtocol {
        // Resolve and store return type
        let resolvedReturnType: any TypeProtocol = node.returnType?.accept(self) ?? VoidType()

        // Create new scope for function body
        let previousEnv = environment
        environment = environment.pushScope()

        // Add parameters to scope and resolve their types
        for param in node.parameters {
            let paramType = param.type.accept(self)
            param.type.resolvedType = paramType
            environment.define(param.name, type: paramType)
        }

        // Type check function body
        if let body = node.body {
            _ = body.accept(self)

            // Check return type consistency
            if let returnStmt = findReturnStatement(in: body) {
                let actualReturnType = returnStmt.accept(self)
                if !actualReturnType.isSameType(as: resolvedReturnType) {
                    diagnostics.typeMismatch(at: returnStmt.range, expected: resolvedReturnType, actual: actualReturnType)
                }
            }
        }

        // Restore previous environment
        environment = previousEnv

        return buildFunctionType(from: node)
    }

    private func findReturnStatement(in block: Block) -> ReturnStatement? {
        for stmt in block.statements {
            if let returnStmt = stmt as? ReturnStatement {
                return returnStmt
            }
            if let nestedBlock = stmt as? Block {
                if let found = findReturnStatement(in: nestedBlock) {
                    return found
                }
            }
        }
        return nil
    }

    public func visit(_ node: ExternDeclaration) -> any TypeProtocol {
        return node.function.accept(self)
    }

    public func visit(_ node: StructDeclaration) -> any TypeProtocol {
        // Ensure the struct type is registered and field types are resolved
        let structType = environment.lookup(node.name) as? StructType ?? buildStructType(from: node)

        // Type-check methods with implicit self in context
        let prevContext = currentStructContext
        currentStructContext = structType

        for method in node.methods {
            // Push scope with implicit 'self'
            let prevEnv = environment
            environment = environment.pushScope()
            environment.define("self", type: structType)

            // Add method parameters to scope and resolve their types
            for param in method.parameters {
                let pType = param.type.accept(self)
                param.type.resolvedType = pType
                environment.define(param.name, type: pType)
            }

            // Type check body and return type
            if let body = method.body {
                _ = body.accept(self)
                if let returnStmt = findReturnStatement(in: body) {
                    let actualReturnType = returnStmt.accept(self)
                    let expectedReturnType: any TypeProtocol = method.returnType?.accept(self) ?? VoidType()
                    if !actualReturnType.isSameType(as: expectedReturnType) {
                        diagnostics.typeMismatch(at: returnStmt.range, expected: expectedReturnType, actual: actualReturnType)
                    }
                }
            }

            // Restore previous environment
            environment = prevEnv
        }

        currentStructContext = prevContext

        return structType
    }

    public func visit(_ node: NominalTypeNode) -> any TypeProtocol {
        var type: any TypeProtocol = switch node.name {
        case "Int": IntType()
        case "Int8": Int8Type()
        case "Int32": Int32Type()
        case "Bool": BoolType()
        case "Void": VoidType()
        default: UnknownType()
        }
        // If unknown, check environment for a user-defined type like a struct
        if type is UnknownType, let envType = environment.lookup(node.name) {
            type = envType
        }
        node.resolvedType = type
        if type is UnknownType {
            diagnostics.unknownType(at: node.range, name: node.name)
        }
        return type
    }

    public func visit(_ node: PointerTypeNode) -> any TypeProtocol {
        let pointeeType = node.pointeeType.accept(self)
        node.pointeeType.resolvedType = pointeeType
        let type = PointerType(pointee: pointeeType)
        node.resolvedType = type
        return type
    }

    public func visit(_: EllipsisTypeNode) -> any TypeProtocol {
        return CVarArgsType()
    }

    public func visit(_ node: VarBinding) -> any TypeProtocol {
        // Handle optional initializer
        if let initExpr = node.value {
            let valueType = initExpr.accept(self)
            if let explicitType = node.type {
                let expectedType = explicitType.accept(self)
                if !valueType.isSameType(as: expectedType) {
                    diagnostics.typeMismatch(at: node.range, expected: expectedType, actual: valueType)
                }
                environment.define(node.name, type: expectedType)
                return expectedType
            } else {
                environment.define(node.name, type: valueType)
                return valueType
            }
        } else {
            // No initializer: allowed for struct fields (handled in buildStructType)
            // For local/global vars, require explicit type and emit diagnostic if missing
            if let explicitType = node.type {
                let expectedType = explicitType.accept(self)
                environment.define(node.name, type: expectedType)
                return expectedType
            } else {
                diagnostics.missingInitializer(at: node.range, name: node.name)
                return UnknownType()
            }
        }
    }

    public func visit(_ node: AssignStatement) -> any TypeProtocol {
        // Legacy path: treat as lvalue assignment to identifier
        let target = IdentifierExpression(range: node.range, name: node.name)
        return checkAssignment(target: target, value: node.value, range: node.range)
    }

    public func visit(_ node: MemberAssignStatement) -> any TypeProtocol {
        // Legacy path: build a member access expression and delegate
        var expr: any Expression = IdentifierExpression(range: node.range, name: node.baseName)
        for member in node.memberPath {
            expr = MemberAccessExpression(range: node.range, base: expr, member: member)
        }
        return checkAssignment(target: expr, value: node.value, range: node.range)
    }

    public func visit(_ node: LValueAssignStatement) -> any TypeProtocol {
        return checkAssignment(target: node.target, value: node.value, range: node.range)
    }

    private func isLValue(_ expr: any Expression) -> (type: any TypeProtocol, ok: Bool) {
        switch expr {
        case let id as IdentifierExpression:
            if let t = environment.lookup(id.name) { return (t, true) }
            if let ctx = currentStructContext, let t = ctx.fields.first(where: { $0.0 == id.name })?.1 { return (t, true) }
            return (UnknownType(), false)
        case let un as UnaryExpression where un.operator == .dereference:
            let opType = un.operand.accept(self)
            if let p = opType as? PointerType { return (p.pointee, true) }
            return (UnknownType(), false)
        case let mem as MemberAccessExpression:
            // Base must be lvalue and struct; and member must exist
            let (baseType, baseOK) = isLValue(mem.base)
            guard baseOK, let structType = baseType as? StructType else { return (UnknownType(), false) }
            if let (_, fieldType) = structType.fields.first(where: { $0.0 == mem.member }) {
                return (fieldType, true)
            }
            return (UnknownType(), false)
        default:
            _ = expr.accept(self)
            return (expr.resolvedType ?? UnknownType(), false)
        }
    }

    private func checkAssignment(target: any Expression, value: any Expression, range: SourceRange) -> any TypeProtocol {
        let (targetType, ok) = isLValue(target)
        if !ok {
            let t = target.accept(self)
            diagnostics.cannotAssign(at: range, type: t)
            return UnknownType()
        }
        let valueType = value.accept(self)
        if !valueType.isSameType(as: targetType) {
            diagnostics.typeMismatch(at: range, expected: targetType, actual: valueType)
            return UnknownType()
        }
        return valueType
    }

    public func visit(_ node: ReturnStatement) -> any TypeProtocol {
        return node.value?.accept(self) ?? VoidType()
    }

    public func visit(_ node: Block) -> any TypeProtocol {
        var lastType: any TypeProtocol = VoidType()
        for stmt in node.statements {
            lastType = stmt.accept(self)
        }
        return lastType
    }

    public func visit(_ node: ExpressionStatement) -> any TypeProtocol {
        return node.expression.accept(self)
    }

    public func visit(_ node: BinaryExpression) -> any TypeProtocol {
        let leftType = node.left.accept(self)
        let rightType = node.right.accept(self)

        var resultType: any TypeProtocol

        // Type checking based on operator type
        switch node.operator {
        case .add, .subtract, .multiply, .divide, .modulo:
            // Arithmetic operations require same integer types
            if !leftType.isSameType(as: rightType) {
                diagnostics.typeMismatch(at: node.range, expected: leftType, actual: rightType)
                resultType = UnknownType()
            } else if leftType is IntType || leftType is Int8Type || leftType is Int32Type {
                resultType = leftType
            } else {
                diagnostics.invalidBinaryOperands(at: node.range, op: symbol(node.operator), lhs: leftType, rhs: rightType)
                resultType = UnknownType()
            }

        case .logicalAnd, .logicalOr:
            // Logical operations require bool operands and result in bool
            if leftType is BoolType && rightType is BoolType {
                resultType = BoolType()
            } else {
                diagnostics.invalidBinaryOperands(at: node.range, op: symbol(node.operator), lhs: leftType, rhs: rightType)
                resultType = UnknownType()
            }

        case .equal, .notEqual, .lessThan, .lessThanOrEqual, .greaterThan, .greaterThanOrEqual:
            // Comparison operations require same types and result in bool
            if !leftType.isSameType(as: rightType) {
                diagnostics.typeMismatch(at: node.range, expected: leftType, actual: rightType)
                resultType = UnknownType()
            } else if leftType is IntType || leftType is Int8Type || leftType is Int32Type || leftType is BoolType {
                resultType = BoolType()
            } else {
                diagnostics.invalidBinaryOperands(at: node.range, op: symbol(node.operator), lhs: leftType, rhs: rightType)
                resultType = UnknownType()
            }
        }

        // Store resolved type in the AST node
        node.resolvedType = resultType
        return resultType
    }

    public func visit(_ node: UnaryExpression) -> any TypeProtocol {
        let operandType = node.operand.accept(self)

        let resultType: any TypeProtocol
        switch node.operator {
        case .negate:
            if operandType is IntType || operandType is Int8Type || operandType is Int32Type {
                resultType = operandType
            } else {
                diagnostics.invalidUnaryOperand(at: node.range, op: "-", type: operandType)
                resultType = UnknownType()
            }
        case .logicalNot:
            if operandType is BoolType {
                resultType = BoolType()
            } else {
                diagnostics.invalidUnaryOperand(at: node.range, op: "!", type: operandType)
                resultType = UnknownType()
            }
        case .dereference:
            if let ptr = operandType as? PointerType {
                resultType = ptr.pointee
            } else {
                diagnostics.cannotDereference(at: node.range, type: operandType)
                resultType = UnknownType()
            }
        case .addressOf:
            // Require operand be an lvalue; result is pointer to its type
            let (lvType, ok) = isLValue(node.operand)
            if ok {
                resultType = PointerType(pointee: lvType)
            } else {
                diagnostics.cannotTakeAddress(at: node.range, type: operandType)
                resultType = UnknownType()
            }
        }

        node.resolvedType = resultType
        return resultType
    }

    public func visit(_ node: CallExpression) -> any TypeProtocol {
        // Resolve callee type
        let calleeType = node.function.accept(self)

        // Gather expected labels from declarations (not types)
        var expectedLabels: [String?] = []
        if let ident = node.function as? IdentifierExpression, let decl = functionDeclsByName[ident.name] {
            expectedLabels = decl.parameters.map { $0.label }
        } else if let mem = node.function as? MemberAccessExpression {
            let baseType = mem.base.resolvedType ?? mem.base.accept(self)
            if let st = baseType as? StructType, let sdecl = structDeclsByName[st.name], let mdecl = sdecl.methods.first(where: { $0.name == mem.member }) {
                expectedLabels = mdecl.parameters.map { $0.label }
            }
        }

        if let funcType = calleeType as? FunctionType {
            let expectedArgCount = funcType.parameters.count
            let actualArgCount = node.arguments.count
            if !funcType.isVariadic, actualArgCount != expectedArgCount {
                diagnostics.argumentCountMismatch(at: node.range, expected: expectedArgCount, actual: actualArgCount)
            } else if funcType.isVariadic, actualArgCount < expectedArgCount {
                diagnostics.argumentCountMismatch(at: node.range, expected: expectedArgCount, actual: actualArgCount)
            }

            for (index, arg) in node.arguments.enumerated() {
                let argType = arg.value.accept(self)
                if index < funcType.parameters.count {
                    let expectedType = funcType.parameters[index]
                    // Label checking against decl-sourced labels
                    if index < expectedLabels.count {
                        if let expectedLabel = expectedLabels[index] {
                            if let got = arg.label {
                                if got != expectedLabel {
                                    diagnostics.incorrectArgumentLabel(at: arg.range, expected: expectedLabel, got: got)
                                }
                            } else {
                                diagnostics.missingArgumentLabel(at: arg.range, expected: expectedLabel)
                            }
                        } else if let got = arg.label {
                            diagnostics.unexpectedArgumentLabel(at: arg.range, got: got)
                        }
                    }

                    if expectedType is CVarArgsType {
                        diagnostics.variadicArgumentType(at: arg.range, type: argType)
                    } else if !argType.isSameType(as: expectedType) {
                        diagnostics.typeMismatch(at: arg.range, expected: expectedType, actual: argType)
                    }
                } else if funcType.isVariadic {
                    diagnostics.variadicArgumentType(at: arg.range, type: argType)
                }
            }

            // Order diagnostic for non-nil labels
            let expectedNonNil = expectedLabels.compactMap { $0 }
            let gotNonNil = node.arguments.compactMap { $0.label }
            if !expectedNonNil.isEmpty,
               Set(expectedNonNil) == Set(gotNonNil),
               expectedNonNil != gotNonNil {
                diagnostics.argumentLabelOrderMismatch(at: node.range, expected: expectedNonNil, got: gotNonNil)
            }

            node.resolvedType = funcType.returnType
            return funcType.returnType
        }

        // Type constructor calls (Int32(x))
        if let ident = node.function as? IdentifierExpression, let targetType = environment.lookup(ident.name) {
            if node.arguments.count == 1 {
                _ = node.arguments[0].value.accept(self)
                node.resolvedType = targetType
                return targetType
            } else {
                diagnostics.notCallable(at: node.range, type: calleeType)
                node.resolvedType = UnknownType()
                return node.resolvedType!
            }
        }

        diagnostics.notCallable(at: node.range, type: calleeType)
        node.resolvedType = UnknownType()
        return node.resolvedType!
    }

    public func visit(_ node: CastExpression) -> any TypeProtocol {
        let targetType = node.targetType.accept(self)
        _ = node.expression.accept(self) // Check expression type but ignore for now

        // Store resolved type in the AST node
        node.resolvedType = targetType
        return targetType
    }

    public func visit(_ node: IdentifierExpression) -> any TypeProtocol {
        var resultType: any TypeProtocol
        if let type = environment.lookup(node.name) {
            resultType = type
        } else if let ctx = currentStructContext,
                  let fieldType = ctx.fields.first(where: { $0.0 == node.name })?.1 {
            // Implicit self.field reference
            resultType = fieldType
        } else {
            diagnostics.undefinedVariable(at: node.range, name: node.name)
            resultType = UnknownType()
        }

        // Store resolved type in the AST node
        node.resolvedType = resultType
        return resultType
    }

    public func visit(_ node: MemberAccessExpression) -> any TypeProtocol {
        let baseType = node.base.accept(self)

        guard let structType = baseType as? StructType else {
            diagnostics.invalidMemberAccess(at: node.range, type: baseType)
            node.resolvedType = UnknownType()
            return node.resolvedType!
        }

        // Find field or method
        if let (_, fieldType) = structType.fields.first(where: { $0.0 == node.member }) {
            node.resolvedType = fieldType
            return fieldType
        }
        if let methodType = structType.methods[node.member] {
            // Expose a callable taking only declared parameters (implicit self is bound by call site)
            let exposed = FunctionType(
                parameters: Array(methodType.parameters.dropFirst()),
                returnType: methodType.returnType,
                isVariadic: methodType.isVariadic,
                labels: Array(methodType.labels.dropFirst())
            )
            node.resolvedType = exposed
            return exposed
        }

        diagnostics.unknownMember(at: node.range, type: baseType, member: node.member)
        node.resolvedType = UnknownType()
        return node.resolvedType!
    }

    public func visit(_ node: IntegerLiteralExpression) -> any TypeProtocol {
        let resultType = IntType()
        node.resolvedType = resultType
        return resultType
    }

    public func visit(_ node: StringLiteralExpression) -> any TypeProtocol {
        let resultType = PointerType(pointee: Int8Type()) // String literals are *Int8
        node.resolvedType = resultType
        return resultType
    }

    public func visit(_ node: BooleanLiteralExpression) -> any TypeProtocol {
        let resultType = BoolType()
        node.resolvedType = resultType
        return resultType
    }

    public func visit(_ node: Parameter) -> any TypeProtocol {
        return node.type.accept(self)
    }

    public func visit(_ node: IfStatement) -> any TypeProtocol {
        for clause in node.clauses {
            let conditionType = clause.condition.accept(self)
            if !(conditionType is BoolType) {
                diagnostics.nonBooleanCondition(at: clause.condition.range, type: conditionType)
            }
            _ = clause.block.accept(self)
        }
        _ = node.elseBlock?.accept(self)
        return VoidType()
    }
}
