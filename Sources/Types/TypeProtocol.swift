import Base

/// Base protocol for all types in the NewLang type system
public protocol TypeProtocol: Sendable, CustomStringConvertible {
    /// Checks if two types are the same (exact match)
    func isSameType(as other: any TypeProtocol) -> Bool

    /// Checks if this type can be implicitly converted to another type
    func isImplicitlyConvertible(to other: any TypeProtocol) -> Bool

    /// Returns true if this is a concrete type (no unknowns)
    var isConcrete: Bool { get }

    /// Returns a unique identifier for this type
    var typeId: String { get }
}
