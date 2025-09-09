import Types

struct UniqueNameMap {
    var baseNames: [String: Int] = [:]

    mutating func next(for name: String) -> String {
        if let count = baseNames[name] {
            baseNames[name] = count + 1
            return "\(name)\(count + 1)"
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
    public let entryBlock = BasicBlock(name: "entry")

    public init(name: String, parameterTypes: [any TypeProtocol], returnType: any TypeProtocol) {
        self.name = name
        self.returnType = returnType
        blocks = [entryBlock]

        // Create function parameters as entry block parameters. Use a temporary
        // block with a fixed name that does not advance the unique name map,
        // so the real entry created later will be named exactly "entry".
        parameters = parameterTypes.enumerated().map { [entryBlock] index, type in
            BlockParameter(
                type: type,
                block: entryBlock,
                index: index
            )
        }
        entryBlock.parameters = parameters
    }

    /// Add a basic block to this function
    public func addBlock(_ block: BasicBlock) {
        block.function = self
        blocks.append(block)
    }

    /// Create a new basic block
    public func createBlock(name: String, parameterTypes: [any TypeProtocol] = []) -> BasicBlock {
        let name = nameMap.next(for: name)
        let block = BasicBlock(name: name, parameterTypes: parameterTypes, function: self)
        addBlock(block)
        return block
    }

    /// Create a new basic block
    public func insertBlock(
        name: String,
        parameterTypes: [any TypeProtocol] = [],
        before block: BasicBlock
    ) -> BasicBlock {
        guard let index = blocks.firstIndex(of: block) else {
            fatalError("Cannot insert block before other block: other block not in function")
        }
        let name = nameMap.next(for: name)
        let block = BasicBlock(name: name, parameterTypes: parameterTypes, function: self)
        blocks.insert(block, at: index)
        return block
    }

    /// Create a new basic block
    public func insertBlock(
        name: String,
        parameterTypes: [any TypeProtocol] = [],
        after block: BasicBlock
    ) -> BasicBlock {
        guard let index = blocks.firstIndex(of: block) else {
            fatalError("Cannot insert block before other block: other block not in function")
        }
        let name = nameMap.next(for: name)
        let block = BasicBlock(name: name, parameterTypes: parameterTypes, function: self)
        blocks.insert(block, at: index + 1)
        return block
    }

    /// Insert a new basic block before an existing block
    public func insertBlock(name: String, before anchor: BasicBlock, parameterTypes: [any TypeProtocol] = []) -> BasicBlock {
        let name = nameMap.next(for: name)
        let block = BasicBlock(name: name, parameterTypes: parameterTypes, function: self)
        if let idx = blocks.firstIndex(where: { ObjectIdentifier($0) == ObjectIdentifier(anchor) }) {
            blocks.insert(block, at: idx)
        } else {
            blocks.append(block)
        }
        return block
    }
}
