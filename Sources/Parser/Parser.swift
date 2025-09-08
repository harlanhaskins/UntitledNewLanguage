import Base
import AST

public final class Parser {
    private let tokens: [Token]
    private var current: Int = 0
    
    public init(tokens: [Token]) {
        self.tokens = tokens
    }
    
    public func parse() throws -> [any Declaration] {
        var declarations: [any Declaration] = []
        
        while !isAtEnd() {
            // Skip newlines at top level
            if check(.newline) {
                advance()
                continue
            }
            
            let declaration = try parseDeclaration()
            declarations.append(declaration)
        }
        
        return declarations
    }
    
    // MARK: - Declarations
    
    private func parseDeclaration() throws -> any Declaration {
        if match(.at) {
            return try parseExternDeclaration()
        }
        
        if match(.func) {
            return try parseFunctionDeclaration()
        }
        
        throw ParseError.unexpectedToken(peek())
    }
    
    private func parseExternDeclaration() throws -> ExternDeclaration {
        let start = previous().range.start
        
        try consume(.extern, "Expected 'extern' after '@'")
        try consume(.leftParen, "Expected '(' after 'extern'")
        
        guard case .identifier(let convention) = peek().kind else {
            throw ParseError.expectedIdentifier(peek())
        }
        advance()
        
        try consume(.rightParen, "Expected ')' after calling convention")
        
        // Skip newlines before function declaration  
        while match(.newline) {}
        
        try consume(.func, "Expected 'func' after extern declaration")
        let function = try parseFunctionDeclaration(isExtern: true)
        
        let end = function.range.end
        let range = SourceRange(start: start, end: end)
        
        return ExternDeclaration(range: range, callingConvention: convention, function: function)
    }
    
    private func parseFunctionDeclaration(isExtern: Bool = false) throws -> FunctionDeclaration {
        let start = previous().range.start
        
        guard case .identifier(let name) = peek().kind else {
            throw ParseError.expectedIdentifier(peek())
        }
        advance()
        
        try consume(.leftParen, "Expected '(' after function name")
        
        var parameters: [Parameter] = []
        if !check(.rightParen) {
            repeat {
                // Check for standalone ellipsis (variadic with no parameter)
                if check(.ellipsis) {
                    advance()
                    // Create a special parameter for standalone variadic
                    let ellipsisRange = previous().range
                    let variadicParam = Parameter(
                        range: ellipsisRange,
                        label: nil,
                        name: "...",
                        type: EllipsisTypeNode(range: ellipsisRange),
                        isVariadic: true
                    )
                    parameters.append(variadicParam)
                    break // Variadic must be last
                } else {
                    let param = try parseParameter()
                    parameters.append(param)
                    
                    // If we hit a comma, continue parsing parameters
                    if !match(.comma) {
                        break
                    }
                }
            } while true
        }
        
        try consume(.rightParen, "Expected ')' after parameters")
        
        var returnType: (any TypeNode)? = nil
        if match(.arrow) {
            returnType = try parseType()
        }
        
        var body: Block? = nil
        if !isExtern {
            body = try parseBlock()
        }
        
        let end = body?.range.end ?? returnType?.range.end ?? previous().range.end
        let range = SourceRange(start: start, end: end)
        
        return FunctionDeclaration(
            range: range,
            name: name,
            parameters: parameters,
            returnType: returnType,
            body: body,
            isExtern: isExtern
        )
    }
    
    private func parseParameter() throws -> Parameter {
        let start = peek().range.start
        
        var label: String? = nil
        var name: String
        
        // Handle parameter label (or underscore for no label)
        if case .underscore = peek().kind {
            advance()
            label = nil
            
            // Next should be parameter name
            guard case .identifier(let paramName) = peek().kind else {
                throw ParseError.expectedIdentifier(peek())
            }
            advance()
            name = paramName
            
        } else if case .identifier(let labelName) = peek().kind {
            advance()
            
            // Check if this is just a single identifier (no label) or label + name
            if case .colon = peek().kind {
                // Single identifier followed by colon = no label, this is the name
                label = nil
                name = labelName
            } else if case .identifier(let paramName) = peek().kind {
                // Two identifiers = label + name
                advance()
                label = labelName
                name = paramName
            } else {
                throw ParseError.expectedIdentifier(peek())
            }
        } else {
            throw ParseError.expectedIdentifier(peek())
        }
        
        try consume(.colon, "Expected ':' after parameter name")
        
        let type = try parseType()
        
        let isVariadic = match(.ellipsis)
        
        let end = isVariadic ? previous().range.end : type.range.end
        let range = SourceRange(start: start, end: end)
        
        return Parameter(range: range, label: label, name: name, type: type, isVariadic: isVariadic)
    }
    
    // MARK: - Types
    
    private func parseType() throws -> any TypeNode {
        if match(.star) {
            let start = previous().range.start
            let pointeeType = try parseType()
            let range = SourceRange(start: start, end: pointeeType.range.end)
            return PointerTypeNode(range: range, pointeeType: pointeeType)
        }

        if match(.ellipsis) {
            let range = previous().range
            return EllipsisTypeNode(range: range)
        }

        guard case .identifier(let name) = peek().kind else {
            throw ParseError.expectedType(peek())
        }
        let token = advance()
        
        return NominalTypeNode(range: token.range, name: name)
    }
    
    // MARK: - Statements
    
    private func parseBlock() throws -> Block {
        let start = peek().range.start
        try consume(.leftBrace, "Expected '{'")
        
        var statements: [any Statement] = []
        
        while !check(.rightBrace) && !isAtEnd() {
            // Skip newlines
            if match(.newline) {
                continue
            }
            
            let stmt = try parseStatement()
            statements.append(stmt)
        }
        
        let endToken = try consume(.rightBrace, "Expected '}'")
        let range = SourceRange(start: start, end: endToken.range.end)
        
        return Block(range: range, statements: statements)
    }
    
    private func parseStatement() throws -> any Statement {
        if match(.var) {
            return try parseVarBinding()
        }
        
        if match(.return) {
            return try parseReturnStatement()
        }
        
        // Check for assignment: identifier = expression
        if isIdentifier() && checkAhead(.assign) {
            return try parseAssignStatement()
        }
        
        // Expression statement (like function calls)
        let expr = try parseExpression()
        
        // Consume optional newline
        _ = match(.newline)

        let range = SourceRange(start: expr.range.start, end: expr.range.end)
        return ExpressionStatement(range: range, expression: expr)
    }
    
    private func parseVarBinding() throws -> VarBinding {
        let start = previous().range.start
        
        guard case .identifier(let name) = peek().kind else {
            throw ParseError.expectedIdentifier(peek())
        }
        advance()
        
        var type: (any TypeNode)? = nil
        if match(.colon) {
            type = try parseType()
        }
        
        try consume(.assign, "Expected '=' in variable binding")
        
        let value = try parseExpression()
        
        // Consume optional newline
        _ = match(.newline)

        let range = SourceRange(start: start, end: value.range.end)
        
        return VarBinding(range: range, name: name, type: type, value: value)
    }
    
    private func parseAssignStatement() throws -> AssignStatement {
        guard case .identifier(let name) = peek().kind else {
            throw ParseError.expectedIdentifier(peek())
        }
        let nameToken = advance()
        let start = nameToken.range.start
        
        try consume(.assign, "Expected '='")
        
        let value = try parseExpression()
        
        // Consume optional newline
        _ = match(.newline)

        let range = SourceRange(start: start, end: value.range.end)
        
        return AssignStatement(range: range, name: name, value: value)
    }
    
    private func parseReturnStatement() throws -> ReturnStatement {
        let start = previous().range.start
        
        var value: (any Expression)? = nil
        if !check(.newline) && !check(.rightBrace) {
            value = try parseExpression()
        }
        
        // Consume optional newline
        _ = match(.newline)

        let end = value?.range.end ?? previous().range.end
        let range = SourceRange(start: start, end: end)
        
        return ReturnStatement(range: range, value: value)
    }
    
    // MARK: - Expressions
    
    private func parseExpression() throws -> any Expression {
        return try parseLogicalOr()
    }
    
    private func parseLogicalOr() throws -> any Expression {
        var expr = try parseLogicalAnd()
        
        while match(.logicalOr) {
            let right = try parseLogicalAnd()
            let range = SourceRange(start: expr.range.start, end: right.range.end)
            expr = BinaryExpression(range: range, left: expr, operator: .logicalOr, right: right)
        }
        
        return expr
    }
    
    private func parseLogicalAnd() throws -> any Expression {
        var expr = try parseAddition()
        
        while match(.logicalAnd) {
            let right = try parseAddition()
            let range = SourceRange(start: expr.range.start, end: right.range.end)
            expr = BinaryExpression(range: range, left: expr, operator: .logicalAnd, right: right)
        }
        
        return expr
    }
    
    private func parseAddition() throws -> any Expression {
        var expr = try parseMultiplication()
        
        while match(.plus) || match(.minus) {
            let op: BinaryOperator = previous().kind == .plus ? .add : .subtract
            let right = try parseMultiplication()
            let range = SourceRange(start: expr.range.start, end: right.range.end)
            expr = BinaryExpression(range: range, left: expr, operator: op, right: right)
        }
        
        return expr
    }
    
    private func parseMultiplication() throws -> any Expression {
        var expr = try parseUnary()
        
        while match(.star) || match(.divide) || match(.modulo) {
            let op: BinaryOperator
            switch previous().kind {
            case .star: op = .multiply
            case .divide: op = .divide
            case .modulo: op = .modulo
            default: fatalError("Unexpected operator")
            }
            
            let right = try parseUnary()
            let range = SourceRange(start: expr.range.start, end: right.range.end)
            expr = BinaryExpression(range: range, left: expr, operator: op, right: right)
        }
        
        return expr
    }
    
    private func parseUnary() throws -> any Expression {
        return try parseCall()
    }
    
    private func parseCall() throws -> any Expression {
        var expr = try parsePrimary()
        
        while match(.leftParen) {
            let start = expr.range.start
            
            var arguments: [any Expression] = []
            if !check(.rightParen) {
                repeat {
                    let arg = try parseExpression()
                    arguments.append(arg)
                } while match(.comma)
            }
            
            let endToken = try consume(.rightParen, "Expected ')' after arguments")
            let range = SourceRange(start: start, end: endToken.range.end)
            
            expr = CallExpression(range: range, function: expr, arguments: arguments)
        }
        
        return expr
    }
    
    private func parsePrimary() throws -> any Expression {
        if case .identifier(let name) = peek().kind {
            let token = advance()
            return IdentifierExpression(range: token.range, name: name)
        }
        
        if case .integerLiteral(let value) = peek().kind {
            let token = advance()
            return LiteralExpression(range: token.range, value: .integer(value))
        }
        
        if case .stringLiteral(let value) = peek().kind {
            let token = advance()
            return LiteralExpression(range: token.range, value: .string(value))
        }
        
        if case .booleanLiteral(let value) = peek().kind {
            let token = advance()
            return LiteralExpression(range: token.range, value: .boolean(value))
        }
        
        throw ParseError.unexpectedToken(peek())
    }
    
    // MARK: - Helper Methods
    
    private func match(_ types: TokenKind...) -> Bool {
        for type in types {
            if check(type) {
                advance()
                return true
            }
        }
        return false
    }
    
    private func check(_ type: TokenKind) -> Bool {
        if isAtEnd() { return false }
        return peek().kind == type
    }
    
    @discardableResult
    private func advance() -> Token {
        if !isAtEnd() { current += 1 }
        return previous()
    }
    
    private func checkAhead(_ type: TokenKind) -> Bool {
        if current + 1 >= tokens.count { return false }
        return tokens[current + 1].kind == type
    }
    
    private func isIdentifier() -> Bool {
        if isAtEnd() { return false }
        if case .identifier(_) = peek().kind {
            return true
        }
        return false
    }
    
    private func isAtEnd() -> Bool {
        return peek().kind == .eof
    }
    
    private func peek() -> Token {
        return tokens[current]
    }
    
    private func previous() -> Token {
        return tokens[current - 1]
    }
    
    @discardableResult
    private func consume(_ type: TokenKind, _ message: String) throws -> Token {
        if check(type) { return advance() }
        throw ParseError.expectedToken(type, peek(), message)
    }
}

public enum ParseError: Error {
    case unexpectedToken(Token)
    case expectedToken(TokenKind, Token, String)
    case expectedIdentifier(Token)
    case expectedType(Token)
}
