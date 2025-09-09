import Base
import Types

public final class FunctionDeclaration: Declaration {
    public let range: SourceRange
    public let name: String
    public let parameters: [Parameter]
    public let returnType: (any TypeNode)?
    public let body: Block?
    public let isExtern: Bool

    public var resolvedReturnType: (any TypeProtocol)? {
        guard let returnType else {
            return VoidType()
        }
        return returnType.resolvedType
    }

    public init(range: SourceRange, name: String, parameters: [Parameter], returnType: (any TypeNode)? = nil, body: Block? = nil, isExtern: Bool = false) {
        self.range = range
        self.name = name
        self.parameters = parameters
        self.returnType = returnType
        self.body = body
        self.isExtern = isExtern
    }

    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class ExternDeclaration: Declaration {
    public let range: SourceRange
    public let callingConvention: String
    public let function: FunctionDeclaration

    public init(range: SourceRange, callingConvention: String, function: FunctionDeclaration) {
        self.range = range
        self.callingConvention = callingConvention
        self.function = function
    }

    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class StructDeclaration: Declaration {
    public let range: SourceRange
    public let name: String
    public let fields: [VarBinding]

    public init(range: SourceRange, name: String, fields: [VarBinding]) {
        self.range = range
        self.name = name
        self.fields = fields
    }

    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}

public final class Parameter: ASTNode {
    public let range: SourceRange
    public let label: String?
    public let name: String
    public var type: any TypeNode
    public let isVariadic: Bool

    public init(range: SourceRange, label: String?, name: String, type: any TypeNode, isVariadic: Bool = false) {
        self.range = range
        self.label = label
        self.name = name
        self.type = type
        self.isVariadic = isVariadic
    }

    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}
