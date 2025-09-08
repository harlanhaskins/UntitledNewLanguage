import Lexer

public struct FunctionDeclaration: Declaration {
    public let range: SourceRange
    public let name: String
    public let parameters: [Parameter]
    public let returnType: (any TypeNode)?
    public let body: Block?
    public let isExtern: Bool
    
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

public struct ExternDeclaration: Declaration {
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

public struct Parameter: ASTNode {
    public let range: SourceRange
    public let label: String?
    public let name: String
    public let type: any TypeNode
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