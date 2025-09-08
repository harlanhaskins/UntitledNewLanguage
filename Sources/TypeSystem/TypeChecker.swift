import AST
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
    
    public init(diagnostics: DiagnosticEngine = DiagnosticEngine()) {
        self.environment = TypeEnvironment()
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
        // First pass: collect function signatures
        for declaration in declarations {
            if let funcDecl = declaration as? FunctionDeclaration {
                let funcType = buildFunctionType(from: funcDecl)
                environment.define(funcDecl.name, type: funcType)
            } else if let externDecl = declaration as? ExternDeclaration {
                let funcType = buildFunctionType(from: externDecl.function)
                environment.define(externDecl.function.name, type: funcType)
            }
        }
        
        // Second pass: type check function bodies
        for declaration in declarations {
            _ = declaration.accept(self)
        }
    }

    private func buildFunctionType(from funcDecl: FunctionDeclaration) -> FunctionType {
        var paramTypes: [any TypeProtocol] = []
        var isVariadic = false
        
        for param in funcDecl.parameters {
            // Use resolved type if available, otherwise resolve it
            let paramType = param.type.resolvedType ?? param.type.accept(self)
            param.type.resolvedType = paramType
            paramTypes.append(paramType)
            if param.isVariadic {
                isVariadic = true
            }
        }

        let returnType: any TypeProtocol = funcDecl.resolvedReturnType ?? funcDecl.returnType?.accept(self) ?? VoidType()

        return FunctionType(parameters: paramTypes, returnType: returnType, isVariadic: isVariadic)
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
            let _ = body.accept(self)
            
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
    
    public func visit(_ node: NominalTypeNode) -> any TypeProtocol {
        let type: any TypeProtocol = switch node.name {
        case "Int": IntType()
        case "Int8": Int8Type()
        case "Int32": Int32Type()
        case "Void": VoidType()
        default: UnknownType()
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
    
    public func visit(_ node: EllipsisTypeNode) -> any TypeProtocol {
        return CVarArgsType()
    }
    
    public func visit(_ node: VarBinding) -> any TypeProtocol {
        let valueType = node.value.accept(self)
        
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
    }
    
    public func visit(_ node: AssignStatement) -> any TypeProtocol {
        // Check if the variable exists in the environment
        guard let existingType = environment.lookup(node.name) else {
            diagnostics.undefinedVariable(at: node.range, name: node.name)
            return UnknownType()
        }
        
        // Type check the value expression
        let valueType = node.value.accept(self)
        
        // Ensure the value type matches the existing variable type
        if !valueType.isSameType(as: existingType) {
            diagnostics.typeMismatch(at: node.range, expected: existingType, actual: valueType)
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
        
        // For arithmetic operations, both operands should be the same integer type
        if !leftType.isSameType(as: rightType) {
            diagnostics.typeMismatch(at: node.range, expected: leftType, actual: rightType)
            resultType = UnknownType()
        } else {
            // Result type is the same as operand type for arithmetic
            switch node.operator {
            case .add, .subtract, .multiply, .divide, .modulo:
                if leftType is IntType || leftType is Int8Type || leftType is Int32Type {
                    resultType = leftType
                } else {
                    diagnostics.invalidOperation(at: node.range, operation: "\(node.operator)", type: leftType)
                    resultType = UnknownType()
                }
            }
        }
        
        // Store resolved type in the AST node
        node.resolvedType = resultType
        return resultType
    }
    
    public func visit(_ node: CallExpression) -> any TypeProtocol {
        let functionType = node.function.accept(self)
        
        var resultType: any TypeProtocol
        
        if let funcType = functionType as? FunctionType {
            // Check argument count and types
            let expectedArgCount = funcType.parameters.count
            let actualArgCount = node.arguments.count
            
            if !funcType.isVariadic && actualArgCount != expectedArgCount {
                diagnostics.argumentCountMismatch(at: node.range, expected: expectedArgCount, actual: actualArgCount)
            } else if funcType.isVariadic && actualArgCount < expectedArgCount {
                diagnostics.argumentCountMismatch(at: node.range, expected: expectedArgCount, actual: actualArgCount)
            }
            
            // Check argument types (up to the number of declared parameters)
            for (index, arg) in node.arguments.enumerated() {
                let argType = arg.accept(self)
                if index < funcType.parameters.count {
                    let expectedType = funcType.parameters[index]
                    
                    if expectedType is CVarArgsType {
                        // For CVarArgs parameters, any type is acceptable
                        diagnostics.variadicArgumentType(at: arg.range, type: argType)
                    } else if !argType.isSameType(as: expectedType) {
                        diagnostics.typeMismatch(at: arg.range, expected: expectedType, actual: argType)
                    }
                } else if funcType.isVariadic {
                    // For variadic functions, additional arguments beyond declared parameters
                    // are accepted as CVarArgs
                    diagnostics.variadicArgumentType(at: arg.range, type: argType)
                }
            }
            
            resultType = funcType.returnType
        } else {
            // Handle type constructor calls (like Int32(x))
            if let identifierExpr = node.function as? IdentifierExpression {
                if let targetType = environment.lookup(identifierExpr.name) {
                    // This is a type cast
                    if node.arguments.count == 1 {
                        let _ = node.arguments[0].accept(self)
                        // For now, allow any integer to integer conversion
                        resultType = targetType
                    } else {
                        diagnostics.notCallable(at: node.range, type: functionType)
                        resultType = UnknownType()
                    }
                } else {
                    diagnostics.notCallable(at: node.range, type: functionType)
                    resultType = UnknownType()
                }
            } else {
                diagnostics.notCallable(at: node.range, type: functionType)
                resultType = UnknownType()
            }
        }
        
        // Store resolved type in the AST node
        node.resolvedType = resultType
        return resultType
    }
    
    public func visit(_ node: CastExpression) -> any TypeProtocol {
        let targetType = node.targetType.accept(self)
        let _ = node.expression.accept(self) // Check expression type but ignore for now
        
        // Store resolved type in the AST node
        node.resolvedType = targetType
        return targetType
    }
    
    public func visit(_ node: IdentifierExpression) -> any TypeProtocol {
        let resultType: any TypeProtocol
        if let type = environment.lookup(node.name) {
            resultType = type
        } else {
            diagnostics.undefinedVariable(at: node.range, name: node.name)
            resultType = UnknownType()
        }
        
        // Store resolved type in the AST node
        node.resolvedType = resultType
        return resultType
    }
    
    public func visit(_ node: LiteralExpression) -> any TypeProtocol {
        let resultType: any TypeProtocol
        switch node.value {
        case .integer(_):
            resultType = IntType() // Default integer type
        case .string(_):
            resultType = PointerType(pointee: Int8Type()) // String literals are *Int8
        }
        
        // Store resolved type in the AST node
        node.resolvedType = resultType
        return resultType
    }
    
    public func visit(_ node: Parameter) -> any TypeProtocol {
        return node.type.accept(self)
    }
}

