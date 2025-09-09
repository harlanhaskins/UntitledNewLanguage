import Base
import Foundation

// MARK: - Concrete Type Implementations

public struct IntType: TypeProtocol {
    public init() {}

    public func isSameType(as other: any TypeProtocol) -> Bool {
        return other is IntType
    }

    public func isImplicitlyConvertible(to other: any TypeProtocol) -> Bool {
        return other is IntType
    }

    public var isConcrete: Bool { true }
    public var typeId: String { "Int" }
    public var description: String { "Int" }
}

public struct Int8Type: TypeProtocol {
    public init() {}

    public func isSameType(as other: any TypeProtocol) -> Bool {
        return other is Int8Type
    }

    public func isImplicitlyConvertible(to other: any TypeProtocol) -> Bool {
        return other is Int8Type
    }

    public var isConcrete: Bool { true }
    public var typeId: String { "Int8" }
    public var description: String { "Int8" }
}

public struct Int32Type: TypeProtocol {
    public init() {}

    public func isSameType(as other: any TypeProtocol) -> Bool {
        return other is Int32Type
    }

    public func isImplicitlyConvertible(to other: any TypeProtocol) -> Bool {
        return other is Int32Type
    }

    public var isConcrete: Bool { true }
    public var typeId: String { "Int32" }
    public var description: String { "Int32" }
}

public struct PointerType: TypeProtocol {
    public let pointee: any TypeProtocol

    public init(pointee: any TypeProtocol) {
        self.pointee = pointee
    }

    public func isSameType(as other: any TypeProtocol) -> Bool {
        guard let otherPtr = other as? PointerType else { return false }
        return pointee.isSameType(as: otherPtr.pointee)
    }

    public func isImplicitlyConvertible(to other: any TypeProtocol) -> Bool {
        guard let otherPtr = other as? PointerType else { return false }
        return pointee.isImplicitlyConvertible(to: otherPtr.pointee)
    }

    public var isConcrete: Bool { pointee.isConcrete }
    public var typeId: String { "*\(pointee.typeId)" }
    public var description: String { "*\(pointee.description)" }
}

public struct FunctionType: TypeProtocol {
    public let parameters: [any TypeProtocol]
    public let returnType: any TypeProtocol
    public let isVariadic: Bool

    public init(parameters: [any TypeProtocol], returnType: any TypeProtocol, isVariadic: Bool = false) {
        self.parameters = parameters
        self.returnType = returnType
        self.isVariadic = isVariadic
    }

    public func isSameType(as other: any TypeProtocol) -> Bool {
        guard let otherFunc = other as? FunctionType else { return false }
        guard parameters.count == otherFunc.parameters.count else { return false }
        guard isVariadic == otherFunc.isVariadic else { return false }
        guard returnType.isSameType(as: otherFunc.returnType) else { return false }

        for (param1, param2) in zip(parameters, otherFunc.parameters) {
            if !param1.isSameType(as: param2) { return false }
        }

        return true
    }

    public func isImplicitlyConvertible(to other: any TypeProtocol) -> Bool {
        // Functions generally can't be implicitly converted
        return isSameType(as: other)
    }

    public var isConcrete: Bool {
        return parameters.allSatisfy(\.isConcrete) && returnType.isConcrete
    }

    public var typeId: String {
        let params = parameters.map(\.typeId).joined(separator: ", ")
        let variadic = isVariadic ? "..." : ""
        return "(\(params)\(variadic)) -> \(returnType.typeId)"
    }

    public var description: String {
        let params = parameters.map(\.description).joined(separator: ", ")
        let variadic = isVariadic ? "..." : ""
        return "(\(params)\(variadic)) -> \(returnType.description)"
    }
}

public struct BoolType: TypeProtocol {
    public init() {}

    public func isSameType(as other: any TypeProtocol) -> Bool {
        return other is BoolType
    }

    public func isImplicitlyConvertible(to other: any TypeProtocol) -> Bool {
        return other is BoolType
    }

    public var isConcrete: Bool { true }
    public var typeId: String { "Bool" }
    public var description: String { "Bool" }
}

public struct VoidType: TypeProtocol {
    public init() {}

    public func isSameType(as other: any TypeProtocol) -> Bool {
        return other is VoidType
    }

    public func isImplicitlyConvertible(to other: any TypeProtocol) -> Bool {
        return other is VoidType
    }

    public var isConcrete: Bool { true }
    public var typeId: String { "Void" }
    public var description: String { "Void" }
}

public struct CVarArgsType: TypeProtocol {
    public init() {}

    public func isSameType(as other: any TypeProtocol) -> Bool {
        return other is CVarArgsType
    }

    public func isImplicitlyConvertible(to other: any TypeProtocol) -> Bool {
        return other is CVarArgsType
    }

    public var isConcrete: Bool { true }
    public var typeId: String { "CVarArgs" }
    public var description: String { "CVarArgs" }
}

public struct UnknownType: TypeProtocol {
    public let id: String

    public init(id: String = UUID().uuidString) {
        self.id = id
    }

    public func isSameType(as other: any TypeProtocol) -> Bool {
        guard let otherUnknown = other as? UnknownType else { return false }
        return id == otherUnknown.id
    }

    public func isImplicitlyConvertible(to _: any TypeProtocol) -> Bool {
        return false // Unknown types can't be converted
    }

    public var isConcrete: Bool { false }
    public var typeId: String { "?\(id)" }
    public var description: String { "?" }
}

// MARK: - Struct Type

public struct StructType: TypeProtocol {
    public let name: String
    public let fields: [(String, any TypeProtocol)] // preserve declaration order
    public let methods: [String: FunctionType]

    public init(name: String, fields: [(String, any TypeProtocol)], methods: [String: FunctionType] = [:]) {
        self.name = name
        self.fields = fields
        self.methods = methods
    }

    public func isSameType(as other: any TypeProtocol) -> Bool {
        guard let o = other as? StructType else { return false }
        return self.name == o.name
    }

    public func isImplicitlyConvertible(to other: any TypeProtocol) -> Bool {
        return isSameType(as: other)
    }

    public var isConcrete: Bool { fields.allSatisfy { $0.1.isConcrete } && methods.values.allSatisfy { $0.isConcrete } }
    public var typeId: String { name }
    public var description: String { name }
}
