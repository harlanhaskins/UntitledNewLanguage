import Types

/// Represents a function in SSA form
public final class SSAFunction {
    public let name: String
    public let parameters: [BlockParameter]
    public let returnType: any TypeProtocol
    public var blocks: [BasicBlock]
    public var entryBlock: BasicBlock?
    
    public init(name: String, parameterTypes: [any TypeProtocol], returnType: any TypeProtocol) {
        self.name = name
        self.returnType = returnType
        self.blocks = []
        
        // Create function parameters as entry block parameters  
        let tempBlock = BasicBlock(name: "entry")
        self.parameters = parameterTypes.enumerated().map { index, type in
            BlockParameter(
                type: type,
                block: tempBlock,
                index: index
            )
        }
    }
    
    /// Add a basic block to this function
    public func addBlock(_ block: BasicBlock) {
        block.function = self
        blocks.append(block)
        
        if entryBlock == nil {
            entryBlock = block
        }
    }
    
    /// Create a new basic block
    public func createBlock(name: String, parameterTypes: [any TypeProtocol] = []) -> BasicBlock {
        let block = BasicBlock(name: name, parameterTypes: parameterTypes, function: self)
        addBlock(block)
        return block
    }
}