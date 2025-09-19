import AST
import Base

public final class Parser {
    private let tokens: [Token]
    private var current: Int = 0

    public init(tokens: [Token]) {
        self.tokens = tokens
    }

    public func parse() throws -> [any Declaration] {
        var declarations: [any Declaration] = []

        while !isAtEnd() {
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

        if match(.struct) {
            return try parseStructDeclaration()
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

        guard case let .identifier(convention) = peek().kind else {
            throw ParseError.expectedIdentifier(peek())
        }
        advance()

        try consume(.rightParen, "Expected ')' after calling convention")

        try consume(.func, "Expected 'func' after extern declaration")
        let function = try parseFunctionDeclaration(isExtern: true)

        let end = function.range.end
        let range = SourceRange(start: start, end: end)

        return ExternDeclaration(range: range, callingConvention: convention, function: function)
    }

    private func parseFunctionDeclaration(isExtern: Bool = false) throws -> FunctionDeclaration {
        let start = previous().range.start

        guard case let .identifier(name) = peek().kind else {
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
            guard case let .identifier(paramName) = peek().kind else {
                throw ParseError.expectedIdentifier(peek())
            }
            advance()
            name = paramName

        } else if case let .identifier(labelName) = peek().kind {
            advance()

            // Check if this is just a single identifier (no label) or label + name
            if case .colon = peek().kind {
                // Single identifier followed by colon = external label equals name
                label = labelName
                name = labelName
            } else if case let .identifier(paramName) = peek().kind {
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

        guard case let .identifier(name) = peek().kind else {
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
            let stmt = try parseStatement()
            statements.append(stmt)
        }

        let endToken = try consume(.rightBrace, "Expected '}'")
        let range = SourceRange(start: start, end: endToken.range.end)

        return Block(range: range, statements: statements)
    }

    private func parseIfStatement() throws -> IfStatement {
        let start = previous().range.start

        var clauses = [IfStatement.Clause]()
        var elseBlock: Block? = nil

        while true {
            let condition = try parseExpression()
            let thenBlock = try parseBlock()
            clauses.append(.init(condition: condition, block: thenBlock))

            if match(.else) {
                if match(.if) {
                    continue
                }
                elseBlock = try parseBlock()
                break
            } else {
                break
            }
        }

        let range = SourceRange(start: start, end: elseBlock?.range.end ?? clauses.last!.block.range.end)
        return IfStatement(range: range, clauses: clauses, elseBlock: elseBlock)
    }

    private func parseStatement() throws -> any Statement {
        if match(.var) {
            return try parseVarBinding()
        }

        if match(.return) {
            return try parseReturnStatement()
        }

        if match(.if) {
            return try parseIfStatement()
        }

        // Attempt general lvalue assignment: <lvalue> '=' expr
        if canStartLValue() {
            let saved = current
            if let lvalue = try? parseLValue(), check(.assign) {
                _ = advance() // consume '='
                let value = try parseExpression()
                let range = SourceRange(start: lvalue.range.start, end: value.range.end)
                return LValueAssignStatement(range: range, target: lvalue, value: value)
            } else {
                // Not an assignment; rewind and treat as expression statement
                current = saved
            }
        }

        // Expression statement (like function calls)
        let expr = try parseExpression()

        let range = SourceRange(start: expr.range.start, end: expr.range.end)
        return ExpressionStatement(range: range, expression: expr)
    }

    private func parseVarBinding(allowOptionalInitializer: Bool = false) throws -> VarBinding {
        let start = previous().range.start

        guard case let .identifier(name) = peek().kind else {
            throw ParseError.expectedIdentifier(peek())
        }
        advance()

        var type: (any TypeNode)? = nil
        if match(.colon) {
            type = try parseType()
        }

        var value: (any Expression)? = nil
        if match(.assign) {
            value = try parseExpression()
        } else if !(allowOptionalInitializer || type != nil) {
            throw ParseError.expectedToken(.assign, peek(), "Expected '=' in variable binding")
        }

        let endLoc = value?.range.end ?? previous().range.end
        let range = SourceRange(start: start, end: endLoc)

        return VarBinding(range: range, name: name, type: type, value: value)
    }

    private func parseStructDeclaration() throws -> StructDeclaration {
        let start = previous().range.start

        // Expect struct name
        guard case let .identifier(name) = peek().kind else {
            throw ParseError.expectedIdentifier(peek())
        }
        advance()

        try consume(.leftBrace, "Expected '{' after struct name")

        var fields: [VarBinding] = []
        var methods: [FunctionDeclaration] = []
        while !check(.rightBrace) && !isAtEnd() {
            if match(.var) {
                let field = try parseVarBinding(allowOptionalInitializer: true)
                fields.append(field)
            } else if match(.func) {
                let method = try parseFunctionDeclaration()
                methods.append(method)
            } else {
                throw ParseError.unexpectedToken(peek())
            }
        }

        let endToken = try consume(.rightBrace, "Expected '}' after struct body")
        let range = SourceRange(start: start, end: endToken.range.end)

        return StructDeclaration(range: range, name: name, fields: fields, methods: methods)
    }

    private func parseAssignStatement() throws -> any Statement {
        guard case let .identifier(baseName) = peek().kind else {
            throw ParseError.expectedIdentifier(peek())
        }
        let nameToken = advance()
        let start = nameToken.range.start

        // Parse optional member path
        var path: [String] = []
        while match(.dot) {
            guard case let .identifier(member) = peek().kind else {
                throw ParseError.expectedIdentifier(peek())
            }
            advance()
            path.append(member)
        }

        try consume(.assign, "Expected '='")
        let value = try parseExpression()
        let range = SourceRange(start: start, end: value.range.end)

        if path.isEmpty {
            return AssignStatement(range: range, name: baseName, value: value)
        } else {
            return MemberAssignStatement(range: range, baseName: baseName, memberPath: path, value: value)
        }
    }

    // Lookahead: identifier ('.' identifier)+ '='
    private func isMemberAssignAhead() -> Bool {
        var i = current
        // first token is identifier (checked by caller)
        i += 1
        guard i < tokens.count else { return false }
        var j = i
        var sawDot = false
        while j + 1 < tokens.count {
            if tokens[j].kind == .dot, case .identifier = tokens[j + 1].kind {
                sawDot = true
                j += 2
            } else {
                break
            }
        }
        if sawDot, j < tokens.count, tokens[j].kind == .assign { return true }
        return false
    }

    // MARK: - LValue Parsing

    private func canStartLValue() -> Bool {
        if isAtEnd() { return false }
        switch peek().kind {
        case .identifier, .star, .leftParen:
            return true
        default:
            return false
        }
    }

    // Parse an lvalue expression supporting identifiers, dereference, member access, and pointer member access
    private func parseLValue() throws -> any Expression {
        // Parse base of lvalue: either *lvalue, (lvalue), or identifier
        let start = peek().range.start
        var expr: any Expression
        if match(.star) {
            let operand = try parseLValue()
            let range = SourceRange(start: start, end: operand.range.end)
            expr = UnaryExpression(range: range, operator: .dereference, operand: operand)
        } else if match(.leftParen) {
            let inner = try parseLValue()
            _ = try consume(.rightParen, "Expected ')' in lvalue")
            expr = inner
        } else if case let .identifier(name) = peek().kind {
            let tok = advance()
            expr = IdentifierExpression(range: tok.range, name: name)
        } else {
            throw ParseError.unexpectedToken(peek())
        }

        // Handle chained . and -> member access
        loop: while true {
            if match(.dot) {
                guard case let .identifier(memberName) = peek().kind else {
                    throw ParseError.expectedIdentifier(peek())
                }
                let memberTok = advance()
                let range = SourceRange(start: expr.range.start, end: memberTok.range.end)
                expr = MemberAccessExpression(range: range, base: expr, member: memberName)
                continue
            }
            if match(.arrow) {
                guard case let .identifier(memberName) = peek().kind else {
                    throw ParseError.expectedIdentifier(peek())
                }
                let memberTok = advance()
                let derefBase = UnaryExpression(range: SourceRange(start: expr.range.start, end: expr.range.end), operator: .dereference, operand: expr)
                let range = SourceRange(start: expr.range.start, end: memberTok.range.end)
                expr = MemberAccessExpression(range: range, base: derefBase, member: memberName)
                continue
            }
            break loop
        }

        return expr
    }

    private func parseReturnStatement() throws -> ReturnStatement {
        let start = previous().range.start

        var value: (any Expression)? = nil

        if !check(.rightBrace) {
            value = try parseExpression()
        }

        let end = value?.range.end ?? previous().range.end
        let range = SourceRange(start: start, end: end)

        return ReturnStatement(range: range, value: value)
    }

    // MARK: - Expressions

    private func parseExpression() throws -> any Expression {
        return try parseExpressionWithPrecedence(minPrecedence: 1)
    }

    /// Parse expression using precedence climbing
    private func parseExpressionWithPrecedence(minPrecedence: Int) throws -> any Expression {
        var left = try parseUnaryOrPrimary()

        while let opToken = getBinaryOperator(),
              getOperatorPrecedence(opToken.kind) >= minPrecedence
        {
            advance() // consume the operator

            let precedence = getOperatorPrecedence(opToken.kind)
            let nextMinPrecedence = isRightAssociative(opToken.kind) ? precedence : precedence + 1
            let right = try parseExpressionWithPrecedence(minPrecedence: nextMinPrecedence)

            let binaryOp = getBinaryOperatorFromToken(opToken.kind)
            let range = SourceRange(start: left.range.start, end: right.range.end)
            left = BinaryExpression(range: range, left: left, operator: binaryOp, right: right)
        }

        return left
    }

    private func parseUnaryOrPrimary() throws -> any Expression {
        // Prefix unary operators bind tighter than any binary operator
        if match(.minus) {
            // Unary negative
            let start = previous().range.start
            let operand = try parseUnaryOrPrimary()
            let range = SourceRange(start: start, end: operand.range.end)
            return UnaryExpression(range: range, operator: .negate, operand: operand)
        }
        if match(.exclamation) {
            // Logical not
            let start = previous().range.start
            let operand = try parseUnaryOrPrimary()
            let range = SourceRange(start: start, end: operand.range.end)
            return UnaryExpression(range: range, operator: .logicalNot, operand: operand)
        }

        if match(.star) {
            // Dereference
            let start = previous().range.start
            let operand = try parseUnaryOrPrimary()
            let range = SourceRange(start: start, end: operand.range.end)
            return UnaryExpression(range: range, operator: .dereference, operand: operand)
        }

        if match(.ampersand) {
            // Address-of
            let start = previous().range.start
            let operand = try parseUnaryOrPrimary()
            let range = SourceRange(start: start, end: operand.range.end)
            return UnaryExpression(range: range, operator: .addressOf, operand: operand)
        }

        return try parseCallOrPrimary()
    }

    private func parseCallOrPrimary() throws -> any Expression {
        var expr = try parsePrimary()

        // Handle chained member access, pointer member access (->), and function calls
        loop: while true {
            if match(.dot) {
                // Member access: expr.identifier
                let start = expr.range.start
                guard case let .identifier(memberName) = peek().kind else {
                    throw ParseError.expectedIdentifier(peek())
                }
                let memberTok = advance()
                let range = SourceRange(start: start, end: memberTok.range.end)
                expr = MemberAccessExpression(range: range, base: expr, member: memberName)
                continue
            }

            if match(.arrow) {
                // Pointer member access: expr->identifier == (*expr).identifier
                let start = expr.range.start
                guard case let .identifier(memberName) = peek().kind else {
                    throw ParseError.expectedIdentifier(peek())
                }
                let memberTok = advance()
                let derefBase = UnaryExpression(range: SourceRange(start: start, end: expr.range.end), operator: .dereference, operand: expr)
                let range = SourceRange(start: start, end: memberTok.range.end)
                expr = MemberAccessExpression(range: range, base: derefBase, member: memberName)
                continue
            }

            if match(.leftParen) {
                // Function call: expr(args)
                let start = expr.range.start
                var arguments: [CallArgument] = []
                if !check(.rightParen) {
                    repeat {
                        // Optional argument label 'identifier:' or '_:'
                        var argLabel: String? = nil
                        let argStart = peek().range.start
                        if case let .identifier(name) = peek().kind, checkAhead(.colon) {
                            _ = advance()
                            _ = try consume(.colon, "Expected ':' after argument label")
                            argLabel = name
                        } else if check(.underscore), checkAhead(.colon) {
                            let tok = advance()
                            _ = try consume(.colon, "Expected ':' after '_' in argument")
                            throw ParseError.underscoreArgumentLabelNotAllowed(tok)
                        }
                        let value = try parseExpression()
                        let argRange = SourceRange(start: argStart, end: value.range.end)
                        arguments.append(CallArgument(label: argLabel, value: value, range: argRange))
                    } while match(.comma)
                }
                let endToken = try consume(.rightParen, "Expected ')' after arguments")
                let range = SourceRange(start: start, end: endToken.range.end)
                expr = CallExpression(range: range, function: expr, arguments: arguments)
                continue
            }

            break loop
        }

        return expr
    }

    private func parsePrimary() throws -> any Expression {
        if case let .identifier(name) = peek().kind {
            let token = advance()
            return IdentifierExpression(range: token.range, name: name)
        }

        if match(.leftParen) {
            let expr = try parseExpression()
            try consume(.rightParen, "Expected ')' after expression")
            return expr
        }

        if case let .integerLiteral(value) = peek().kind {
            let token = advance()
            return IntegerLiteralExpression(range: token.range, value: value)
        }

        if case let .stringLiteral(value) = peek().kind {
            let token = advance()
            return StringLiteralExpression(range: token.range, value: value)
        }

        if case let .booleanLiteral(value) = peek().kind {
            let token = advance()
            return BooleanLiteralExpression(range: token.range, value: value)
        }

        throw ParseError.unexpectedToken(peek())
    }

    // MARK: - Operator Precedence Helpers

    private func getBinaryOperator() -> Token? {
        let token = peek()
        switch token.kind {
        case .plus, .minus, .star, .divide, .modulo, .logicalAnd, .logicalOr,
             .equal, .notEqual, .lessThan, .lessThanOrEqual, .greaterThan, .greaterThanOrEqual:
            return token
        default:
            return nil
        }
    }

    private func getOperatorPrecedence(_ tokenKind: TokenKind) -> Int {
        switch tokenKind {
        case .logicalOr:
            return 1
        case .logicalAnd:
            return 2
        case .equal, .notEqual, .lessThan, .lessThanOrEqual, .greaterThan, .greaterThanOrEqual:
            return 3
        case .plus, .minus:
            return 4
        case .star, .divide, .modulo:
            return 5
        default:
            return 0
        }
    }

    private func isRightAssociative(_: TokenKind) -> Bool {
        // All our current operators are left-associative
        return false
    }

    private func getBinaryOperatorFromToken(_ tokenKind: TokenKind) -> BinaryOperator {
        switch tokenKind {
        case .plus: return .add
        case .minus: return .subtract
        case .star: return .multiply
        case .divide: return .divide
        case .modulo: return .modulo
        case .logicalAnd: return .logicalAnd
        case .logicalOr: return .logicalOr
        case .equal: return .equal
        case .notEqual: return .notEqual
        case .lessThan: return .lessThan
        case .lessThanOrEqual: return .lessThanOrEqual
        case .greaterThan: return .greaterThan
        case .greaterThanOrEqual: return .greaterThanOrEqual
        default: fatalError("Unexpected binary operator token: \(tokenKind)")
        }
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
        if case .identifier = peek().kind {
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
    case underscoreArgumentLabelNotAllowed(Token)
}

extension ParseError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .unexpectedToken(tok):
            return "parse error at \(format(tok.range.start)): unexpected token '\(tokenString(tok))'"
        case let .expectedToken(expected, actual, message):
            return "parse error at \(format(actual.range.start)): \(message); found '\(tokenString(actual))', expected '\(tokenKindString(expected))'"
        case let .expectedIdentifier(tok):
            return "parse error at \(format(tok.range.start)): expected identifier, found '\(tokenString(tok))'"
        case let .expectedType(tok):
            return "parse error at \(format(tok.range.start)): expected type name, found '\(tokenString(tok))'"
        case let .underscoreArgumentLabelNotAllowed(tok):
            return "parse error at \(format(tok.range.start)): '_' is not a valid argument label"
        }
    }

    private func tokenString(_ token: Token) -> String {
        switch token.kind {
        case let .identifier(name): name
        case let .integerLiteral(v): v
        case let .stringLiteral(v): "\"\(v)\""
        case let .booleanLiteral(b): b ? "true" : "false"
        case .plus: "+"
        case .minus: "-"
        case .exclamation: "!"
        case .star: "*"
        case .divide: "/"
        case .modulo: "%"
        case .assign: "="
        case .arrow: "->"
        case .logicalAnd: "&&"
        case .logicalOr: "||"
        case .equal: "=="
        case .notEqual: "!="
        case .lessThan: "<"
        case .lessThanOrEqual: "<="
        case .greaterThan: ">"
        case .greaterThanOrEqual: ">="
        case .leftParen: "("
        case .rightParen: ")"
        case .leftBrace: "{"
        case .rightBrace: "}"
        case .colon: ":"
        case .comma: ","
        case .underscore: "_"
        case .at: "@"
        case .ellipsis: "..."
        case .dot: "."
        case .ampersand: "&"
        case .eof: "<eof>"
        case .func: "func"
        case .var: "var"
        case .struct: "struct"
        case .return: "return"
        case .extern: "extern"
        case .if: "if"
        case .else: "else"
        case .true: "true"
        case .false: "false"
        case let .unknown(char): "\(char)"
        }
    }

    private func tokenKindString(_ kind: TokenKind) -> String {
        // We only need symbolic rendering for a subset; reuse same mapping
        return tokenString(Token(kind: kind, range: SourceRange(start: .init(line: 0, column: 0, offset: 0), end: .init(line: 0, column: 0, offset: 0))))
    }

    private func format(_ loc: SourceLocation) -> String {
        return "\(loc.line):\(loc.column)"
    }
}
