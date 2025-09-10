import Types

/// Types that can be visited by an SSAFunctionVisitor implement this.
public protocol SSAVisitable {
    func accept<W: SSAFunctionVisitor>(_ walker: W) -> W.Result
}

/// Visitor protocol mirroring ASTWalker, specialized to SSA IR.
public protocol SSAFunctionVisitor {
    associatedtype Result

    // Functions / blocks
    func visit(_ node: SSAFunction) -> Result
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
