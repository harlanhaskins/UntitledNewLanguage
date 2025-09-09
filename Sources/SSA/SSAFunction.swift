import Types

struct UniqueNameMap {
    var baseNames: [String: Int] = [:]

    mutating func next(for name: String) -> String {
        if let count = baseNames[name] {
            baseNames[name] = count + 1
            return "\(name)_\(count + 1)"
        } else {
            baseNames[name] = 0
            return name
        }
    }
}

/// Represents a function in SSA form
public final class SSAFunction {
    private var nameMap = UniqueNameMap()
    public let name: String
    public let parameters: [BlockParameter]
    public let returnType: any TypeProtocol
    public var blocks: [BasicBlock]
    public var entryBlock: BasicBlock?

    public init(name: String, parameterTypes: [any TypeProtocol], returnType: any TypeProtocol) {
        self.name = name
        self.returnType = returnType
        blocks = []

        // Create function parameters as entry block parameters
        let tempBlock = BasicBlock(name: nameMap.next(for: "entry"))
        parameters = parameterTypes.enumerated().map { index, type in
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
        let name = nameMap.next(for: name)
        let block = BasicBlock(name: name, parameterTypes: parameterTypes, function: self)
        addBlock(block)
        return block
    }
}
