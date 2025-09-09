import Base
import Types

public protocol ASTNode {
    var range: SourceRange { get }
    func accept<W: ASTWalker>(_ walker: W) -> W.Result
}

public protocol Declaration: ASTNode {}
public protocol Expression: ASTNode {
    var resolvedType: (any TypeProtocol)? { get }
}

public protocol Statement: ASTNode {}
public protocol TypeNode: ASTNode {
    var resolvedType: (any TypeProtocol)? { get set }
}

public protocol ASTWalker {
    associatedtype Result

    // Declarations
    func visit(_ node: FunctionDeclaration) -> Result
    func visit(_ node: ExternDeclaration) -> Result

    // Types
    func visit(_ node: NominalTypeNode) -> Result
    func visit(_ node: PointerTypeNode) -> Result
    func visit(_ node: EllipsisTypeNode) -> Result

    // Statements
    func visit(_ node: VarBinding) -> Result
    func visit(_ node: AssignStatement) -> Result
    func visit(_ node: ReturnStatement) -> Result
    func visit(_ node: Block) -> Result
    func visit(_ node: ExpressionStatement) -> Result
    func visit(_ node: IfStatement) -> Result

    // Expressions
    func visit(_ node: BinaryExpression) -> Result
    func visit(_ node: UnaryExpression) -> Result
    func visit(_ node: CallExpression) -> Result
    func visit(_ node: CastExpression) -> Result
    func visit(_ node: IdentifierExpression) -> Result
    func visit(_ node: IntegerLiteralExpression) -> Result
    func visit(_ node: StringLiteralExpression) -> Result
    func visit(_ node: BooleanLiteralExpression) -> Result

    // Parameters
    func visit(_ node: Parameter) -> Result
}
