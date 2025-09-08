import Base

public final class Block: Statement {
    public let range: SourceRange
    public let statements: [any Statement]
    
    public init(range: SourceRange, statements: [any Statement]) {
        self.range = range
        self.statements = statements
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class VarBinding: Statement {
    public let range: SourceRange
    public let name: String
    public let type: (any TypeNode)?
    public let value: any Expression
    
    public init(range: SourceRange, name: String, type: (any TypeNode)? = nil, value: any Expression) {
        self.range = range
        self.name = name
        self.type = type
        self.value = value
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class ReturnStatement: Statement {
    public let range: SourceRange
    public let value: (any Expression)?
    
    public init(range: SourceRange, value: (any Expression)? = nil) {
        self.range = range
        self.value = value
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class AssignStatement: Statement {
    public let range: SourceRange
    public let name: String
    public let value: any Expression
    
    public init(range: SourceRange, name: String, value: any Expression) {
        self.range = range
        self.name = name
        self.value = value
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class ExpressionStatement: Statement {
    public let range: SourceRange
    public let expression: any Expression
    
    public init(range: SourceRange, expression: any Expression) {
        self.range = range
        self.expression = expression
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}
