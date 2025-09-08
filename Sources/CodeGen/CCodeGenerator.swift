import Base
import AST
import Types

/// Generates C code from a typed NewLang AST
public final class CCodeGenerator {
    private var output: String = ""
    private var indentLevel: Int = 0
    
    public init() {}
    
    public func generate(declarations: [any Declaration]) -> String {
        output = ""
        indentLevel = 0
        
        // Generate includes
        emit("#include <stdio.h>")
        emit("#include <stdarg.h>")
        emit("#include <stdint.h>")
        emit("")
        
        // Generate forward declarations
        for declaration in declarations {
            if let funcDecl = declaration as? FunctionDeclaration, !funcDecl.isExtern {
                emitFunctionForwardDeclaration(funcDecl)
            }
        }
        
        if declarations.contains(where: { ($0 as? FunctionDeclaration)?.isExtern == false }) {
            emit("")
        }
        
        // Generate function implementations
        for declaration in declarations {
            generateDeclaration(declaration)
        }
        
        return output
    }
    
    private func emit(_ text: String) {
        let indent = String(repeating: "    ", count: indentLevel)
        output += indent + text + "\n"
    }
    
    private func emitInline(_ text: String) {
        output += text
    }
    
    private func generateDeclaration(_ node: any Declaration) {
        if let funcDecl = node as? FunctionDeclaration {
            generateFunctionDeclaration(funcDecl)
        } else if let externDecl = node as? ExternDeclaration {
            generateExternDeclaration(externDecl)
        }
    }
    
    private func generateExternDeclaration(_ node: ExternDeclaration) {
        // Extern declarations are handled via #include directives
        // printf is already included via stdio.h
    }
    
    private func emitFunctionForwardDeclaration(_ node: FunctionDeclaration) {
        let returnType = node.resolvedReturnType ?? VoidType()
        let returnTypeStr = cType(for: returnType)
        emitInline(returnTypeStr + " " + node.name + "(")
        
        for (index, param) in node.parameters.enumerated() {
            if index > 0 { emitInline(", ") }
            if param.isVariadic {
                emitInline("...")
            } else {
                let paramTypeStr = cType(for: param.type.resolvedType!)
                emitInline(paramTypeStr + " " + param.name)
            }
        }
        
        emitInline(");")
        output += "\n"
    }
    
    private func generateFunctionDeclaration(_ node: FunctionDeclaration) {
        if node.isExtern { return }
        
        let returnType = node.resolvedReturnType ?? VoidType()
        let returnTypeStr = cType(for: returnType)
        emitInline(returnTypeStr + " " + node.name + "(")
        
        for (index, param) in node.parameters.enumerated() {
            if index > 0 { emitInline(", ") }
            if param.isVariadic {
                emitInline("...")
            } else {
                let paramTypeStr = cType(for: param.type.resolvedType!)
                emitInline(paramTypeStr + " " + param.name)
            }
        }
        
        emitInline(") {")
        output += "\n"
        
        if let body = node.body {
            indentLevel += 1
            generateStatement(body)
            indentLevel -= 1
        }
        
        emit("}")
        emit("")
    }
    
    private func generateStatement(_ node: any Statement) {
        if let block = node as? Block {
            generateBlock(block)
        } else if let varBinding = node as? VarBinding {
            generateVarBinding(varBinding)
        } else if let assignStmt = node as? AssignStatement {
            generateAssignStatement(assignStmt)
        } else if let returnStmt = node as? ReturnStatement {
            generateReturnStatement(returnStmt)
        } else if let exprStmt = node as? ExpressionStatement {
            generateExpressionStatement(exprStmt)
        }
    }
    
    private func generateBlock(_ node: Block) {
        for stmt in node.statements {
            generateStatement(stmt)
        }
    }
    
    private func generateVarBinding(_ node: VarBinding) {
        let typeStr = cType(for: node.value.resolvedType!)
        let valueStr = generateExpression(node.value)
        emit("\(typeStr) \(node.name) = \(valueStr);")
    }
    
    private func generateAssignStatement(_ node: AssignStatement) {
        let valueStr = generateExpression(node.value)
        emit("\(node.name) = \(valueStr);")
    }
    
    private func generateReturnStatement(_ node: ReturnStatement) {
        if let value = node.value {
            let valueStr = generateExpression(value)
            emit("return \(valueStr);")
        } else {
            emit("return;")
        }
    }
    
    private func generateExpressionStatement(_ node: ExpressionStatement) {
        let exprStr = generateExpression(node.expression)
        emit("\(exprStr);")
    }
    
    private func generateExpression(_ node: any Expression) -> String {
        if let binary = node as? BinaryExpression {
            return generateBinaryExpression(binary)
        } else if let call = node as? CallExpression {
            return generateCallExpression(call)
        } else if let cast = node as? CastExpression {
            return generateCastExpression(cast)
        } else if let identifier = node as? IdentifierExpression {
            return generateIdentifierExpression(identifier)
        } else if let literal = node as? LiteralExpression {
            return generateLiteralExpression(literal)
        } else {
            return "/* unknown expression */"
        }
    }
    
    private func generateBinaryExpression(_ node: BinaryExpression) -> String {
        let leftStr = generateExpression(node.left)
        let rightStr = generateExpression(node.right)
        let opStr = cOperator(for: node.operator)
        return "(\(leftStr) \(opStr) \(rightStr))"
    }
    
    private func generateCallExpression(_ node: CallExpression) -> String {
        // Check if this is a type constructor call (like Int32(x))
        if let identifierExpr = node.function as? IdentifierExpression,
           let resolvedType = node.resolvedType,
           node.arguments.count == 1 {
            // Check if the function name matches a type name
            let typeName = identifierExpr.name
            if typeName == "Int32" || typeName == "Int8" || typeName == "Int" {
                // This is a type cast, generate as C cast
                let targetTypeStr = cType(for: resolvedType)
                let argStr = generateExpression(node.arguments[0])
                return "((\(targetTypeStr))\(argStr))"
            }
        }
        
        // Regular function call
        let funcStr = generateExpression(node.function)
        let argsStr = node.arguments.map { generateExpression($0) }.joined(separator: ", ")
        return "\(funcStr)(\(argsStr))"
    }
    
    private func generateCastExpression(_ node: CastExpression) -> String {
        let targetTypeStr = cType(for: node.resolvedType!)
        let exprStr = generateExpression(node.expression)
        return "((\(targetTypeStr))\(exprStr))"
    }
    
    private func generateIdentifierExpression(_ node: IdentifierExpression) -> String {
        return node.name
    }
    
    private func generateLiteralExpression(_ node: LiteralExpression) -> String {
        switch node.value {
        case .integer(let value):
            return value
        case .string(let value):
            return "\"\(value)\""
        }
    }
    
    // MARK: - Type Conversion Helpers
    
    private func cType(for type: any TypeProtocol) -> String {
        if type is IntType {
            return "int64_t"
        } else if type is Int8Type {
            return "char"
        } else if type is Int32Type {
            return "int32_t"
        } else if type is VoidType {
            return "void"
        } else if let pointerType = type as? PointerType {
            let pointeeStr = cType(for: pointerType.pointee)
            return "\(pointeeStr)*"
        } else if type is FunctionType {
            return "/* function type */"
        } else {
            return "int" // fallback
        }
    }
    
    private func cOperator(for op: BinaryOperator) -> String {
        switch op {
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "*"
        case .divide: return "/"
        case .modulo: return "%"
        }
    }
}
