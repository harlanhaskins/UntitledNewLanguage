import Lexer

public struct NominalType: TypeNode {
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

public struct PointerType: TypeNode {
    public let range: SourceRange
    public let pointeeType: any TypeNode
    
    public init(range: SourceRange, pointeeType: any TypeNode) {
        self.range = range
        self.pointeeType = pointeeType
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}
