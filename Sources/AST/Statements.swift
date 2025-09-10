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
    public let value: (any Expression)?

    public init(range: SourceRange, name: String, type: (any TypeNode)? = nil, value: (any Expression)? = nil) {
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

public final class MemberAssignStatement: Statement {
    public let range: SourceRange
    public let baseName: String
    public let memberPath: [String]
    public let value: any Expression

    public init(range: SourceRange, baseName: String, memberPath: [String], value: any Expression) {
        self.range = range
        self.baseName = baseName
        self.memberPath = memberPath
        self.value = value
    }

    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

/// General assignment statement that supports arbitrary lvalue targets
public final class LValueAssignStatement: Statement {
    public let range: SourceRange
    public let target: any Expression // must be an lvalue
    public let value: any Expression

    public init(range: SourceRange, target: any Expression, value: any Expression) {
        self.range = range
        self.target = target
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

public final class IfStatement: Statement {
    public struct Clause {
        public var condition: any Expression
        public var block: Block

        public init(condition: any Expression, block: Block) {
            self.condition = condition
            self.block = block
        }
    }

    public let range: SourceRange
    public let clauses: [Clause]
    public let elseBlock: Block?

    public init(range: SourceRange, clauses: [Clause], elseBlock: Block?) {
        self.range = range
        self.clauses = clauses
        self.elseBlock = elseBlock
    }

    public func accept<W>(_ walker: W) -> W.Result where W: ASTWalker {
        walker.visit(self)
    }
}
