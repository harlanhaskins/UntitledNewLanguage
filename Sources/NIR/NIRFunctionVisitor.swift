import Types

/// Types that can be visited by an NIRFunctionVisitor implement this.
public protocol NIRVisitable {
    func accept<W: NIRFunctionVisitor>(_ walker: W) -> W.Result
}

/// Visitor protocol mirroring ASTWalker, specialized to NIR IR.
public protocol NIRFunctionVisitor {
    associatedtype Result

    // Functions / blocks
    func visit(_ node: NIRFunction) -> Result
    func visit(_ node: BasicBlock) -> Result

    // Instructions
    func visit(_ node: BinaryOp) -> Result
    func visit(_ node: UnaryOp) -> Result
    func visit(_ node: FieldExtractInst) -> Result
    func visit(_ node: FieldAddressInst) -> Result
    func visit(_ node: CallInst) -> Result
    func visit(_ node: AllocaInst) -> Result
    func visit(_ node: LoadInst) -> Result
    func visit(_ node: StoreInst) -> Result
    func visit(_ node: CastInst) -> Result

    // Terminators
    func visit(_ node: JumpTerm) -> Result
    func visit(_ node: BranchTerm) -> Result
    func visit(_ node: ReturnTerm) -> Result
}
