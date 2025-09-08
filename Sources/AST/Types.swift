import Base
import Types

public final class NominalTypeNode: TypeNode {
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

public final class EllipsisTypeNode: TypeNode {
    public let range: SourceRange
    public var resolvedType: (any TypeProtocol)?

    public init(range: SourceRange) {
        self.range = range
        self.resolvedType = CVarArgsType()
    }

    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }

}

public final class PointerTypeNode: TypeNode {
    public let range: SourceRange
    public var pointeeType: any TypeNode
    public var resolvedType: (any TypeProtocol)?

    public init(range: SourceRange, pointeeType: any TypeNode) {
        self.range = range
        self.pointeeType = pointeeType
    }
    
    public func accept<W: ASTWalker>(_ walker: W) -> W.Result {
        return walker.visit(self)
    }
}
