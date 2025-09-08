import Lexer

public protocol ASTNode {
    var range: SourceRange { get }
    func accept<W: ASTWalker>(_ walker: W) -> W.Result
}

public protocol Declaration: ASTNode {}
public protocol Expression: ASTNode {}
public protocol Statement: ASTNode {}
public protocol TypeNode: ASTNode {}

public protocol ASTWalker {
    associatedtype Result
    
    // Declarations
    func visit(_ node: FunctionDeclaration) -> Result
    func visit(_ node: ExternDeclaration) -> Result
    
    // Types
    func visit(_ node: NominalType) -> Result
    func visit(_ node: PointerType) -> Result
    
    // Statements
    func visit(_ node: VarBinding) -> Result
    func visit(_ node: ReturnStatement) -> Result
    func visit(_ node: Block) -> Result
    
    // Expressions
    func visit(_ node: BinaryExpression) -> Result
    func visit(_ node: CallExpression) -> Result
    func visit(_ node: CastExpression) -> Result
    func visit(_ node: IdentifierExpression) -> Result
    func visit(_ node: LiteralExpression) -> Result
    
    // Parameters
    func visit(_ node: Parameter) -> Result
}
