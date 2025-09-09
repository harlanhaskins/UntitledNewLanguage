import Base
import Types

public enum BinaryOperator {
    case add, subtract, multiply, divide, modulo
    case logicalAnd, logicalOr
    case equal, notEqual, lessThan, lessThanOrEqual, greaterThan, greaterThanOrEqual
}

public enum UnaryOperator {
    case negate
    case logicalNot
}

public final class UnaryExpression: Expression {
    public let range: SourceRange
    public let `operator`: UnaryOperator
    public let operand: any Expression
    public var resolvedType: (any TypeProtocol)?

    public init(range: SourceRange, operator: UnaryOperator, operand: any Expression) {
        self.range = range
        self.operator = `operator`
        self.operand = operand
        self.resolvedType = nil
    }

    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
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
        self.operator = `operator`
        self.right = right
        resolvedType = nil
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
        resolvedType = nil
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
        resolvedType = nil
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
        resolvedType = nil
    }

    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class IntegerLiteralExpression: Expression {
    public let range: SourceRange
    public let value: String
    public var resolvedType: (any TypeProtocol)?

    public init(range: SourceRange, value: String) {
        self.range = range
        self.value = value
        resolvedType = nil
    }

    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class StringLiteralExpression: Expression {
    public let range: SourceRange
    public let value: String
    public var resolvedType: (any TypeProtocol)?

    public init(range: SourceRange, value: String) {
        self.range = range
        self.value = value
        resolvedType = nil
    }

    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class BooleanLiteralExpression: Expression {
    public let range: SourceRange
    public let value: Bool
    public var resolvedType: (any TypeProtocol)?

    public init(range: SourceRange, value: Bool) {
        self.range = range
        self.value = value
        resolvedType = nil
    }

    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class MemberAccessExpression: Expression {
    public let range: SourceRange
    public let base: any Expression
    public let member: String
    public var resolvedType: (any TypeProtocol)?

    public init(range: SourceRange, base: any Expression, member: String) {
        self.range = range
        self.base = base
        self.member = member
        self.resolvedType = nil
    }

    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}
