import Lexer

public enum BinaryOperator {
    case add, subtract, multiply, divide, modulo
}

public struct BinaryExpression: Expression {
    public let range: SourceRange
    public let left: any Expression
    public let `operator`: BinaryOperator
    public let right: any Expression
    
    public init(range: SourceRange, left: any Expression, operator: BinaryOperator, right: any Expression) {
        self.range = range
        self.left = left
        self.`operator` = `operator`
        self.right = right
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public struct CallExpression: Expression {
    public let range: SourceRange
    public let function: any Expression
    public let arguments: [any Expression]
    
    public init(range: SourceRange, function: any Expression, arguments: [any Expression]) {
        self.range = range
        self.function = function
        self.arguments = arguments
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public struct CastExpression: Expression {
    public let range: SourceRange
    public let targetType: any TypeNode
    public let expression: any Expression
    
    public init(range: SourceRange, targetType: any TypeNode, expression: any Expression) {
        self.range = range
        self.targetType = targetType
        self.expression = expression
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public struct IdentifierExpression: Expression {
    public let range: SourceRange
    public let name: String
    
    public init(range: SourceRange, name: String) {
        self.range = range
        self.name = name
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public enum LiteralValue {
    case integer(String)
    case string(String)
}

public struct LiteralExpression: Expression {
    public let range: SourceRange
    public let value: LiteralValue
    
    public init(range: SourceRange, value: LiteralValue) {
        self.range = range
        self.value = value
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}