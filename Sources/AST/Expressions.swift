import Base
import Types

public enum BinaryOperator {
    case add, subtract, multiply, divide, modulo
    case logicalAnd, logicalOr
}

public final class BinaryExpression: Expression {
    public let range: SourceRange
    public let left: any Expression
    public let `operator`: BinaryOperator
    public let right: any Expression
    public var resolvedType: (any TypeProtocol)?
    
    public init(range: SourceRange, left: any Expression, operator: BinaryOperator, right: any Expression) {
        self.range = range
        self.left = left
        self.`operator` = `operator`
        self.right = right
        self.resolvedType = nil
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class CallExpression: Expression {
    public let range: SourceRange
    public let function: any Expression
    public let arguments: [any Expression]
    public var resolvedType: (any TypeProtocol)?
    
    public init(range: SourceRange, function: any Expression, arguments: [any Expression]) {
        self.range = range
        self.function = function
        self.arguments = arguments
        self.resolvedType = nil
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class CastExpression: Expression {
    public let range: SourceRange
    public let targetType: any TypeNode
    public let expression: any Expression
    public var resolvedType: (any TypeProtocol)?
    
    public init(range: SourceRange, targetType: any TypeNode, expression: any Expression) {
        self.range = range
        self.targetType = targetType
        self.expression = expression
        self.resolvedType = nil
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class IdentifierExpression: Expression {
    public let range: SourceRange
    public let name: String
    public var resolvedType: (any TypeProtocol)?
    
    public init(range: SourceRange, name: String) {
        self.range = range
        self.name = name
        self.resolvedType = nil
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public enum LiteralValue {
    case integer(String)
    case string(String)
    case boolean(Bool)
}

public final class LiteralExpression: Expression {
    public let range: SourceRange
    public let value: LiteralValue
    public var resolvedType: (any TypeProtocol)?
    
    public init(range: SourceRange, value: LiteralValue) {
        self.range = range
        self.value = value
        self.resolvedType = nil
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}
