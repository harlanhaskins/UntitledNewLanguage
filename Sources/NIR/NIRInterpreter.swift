import Base
import Foundation
import Types

/// A simple interpreter for NIRFunction that can execute non-extern code and
/// return built-in values. External function calls are not supported.
public final class NIRInterpreter {
    // Public result type callers can observe
    public enum BuiltinValue: Equatable, CustomStringConvertible {
        case void
        case int(Int)
        case int8(Int8)
        case int32(Int32)
        case bool(Bool)
        case string(String)

        public var description: String {
            switch self {
            case .void: return "void"
            case let .int(v): return "\(v)"
            case let .int8(v): return "\(v)"
            case let .int32(v): return "\(v)"
            case let .bool(v): return "\(v)"
            case let .string(s): return "\(s)"
            }
        }
    }

    /// Type alias for builtin function closures
    public typealias BuiltinFunction = ([BuiltinValue]) throws -> BuiltinValue

    /// Registry for builtin functions that can be called from interpreted code
    public final class BuiltinRegistry {
        private var builtins: [String: BuiltinFunction] = [:]

        public init() {}

        /// Register a builtin function with the given name
        public func register(_ name: String, function: @escaping BuiltinFunction) {
            builtins[name] = function
        }

        /// Remove a builtin function
        public func unregister(_ name: String) {
            builtins.removeValue(forKey: name)
        }

        /// Get a builtin function by name
        func get(_ name: String) -> BuiltinFunction? {
            return builtins[name]
        }

        /// Check if a builtin function exists
        public func contains(_ name: String) -> Bool {
            return builtins[name] != nil
        }

        /// Get all registered builtin function names
        public var registeredNames: [String] {
            return Array(builtins.keys).sorted()
        }
    }

    public enum Error: Swift.Error, CustomStringConvertible {
        case unknownFunction(String)
        case invalidArgumentCount(expected: Int, got: Int)
        case missingValue(String)
        case invalidPointer
        case typeMismatch(String)

        public var description: String {
            switch self {
            case let .unknownFunction(n): return "Unknown function: \(n)"
            case let .invalidArgumentCount(e, g): return "Invalid argument count: expected \(e), got \(g)"
            case let .missingValue(d): return "Missing value: \(d)"
            case .invalidPointer: return "Invalid pointer"
            case let .typeMismatch(d): return "Type mismatch: \(d)"
            }
        }
    }

    // Internal runtime value representation
    private enum Value: CustomStringConvertible {
        case void
        case int(Int)
        case int8(Int8)
        case int32(Int32)
        case bool(Bool)
        case string(String)
        case pointer(Address)
        case structValue([String: Value])

        init(_ c: Constant) {
            self = switch c.value {
            case .void: .void
            case let .boolean(b): .bool(b)
            case let .integer(i):
                switch c.type {
                case is Int8Type:
                    .int8(Int8(exactly: i)!)
                case is Int32Type:
                    .int32(Int32(exactly: i)!)
                default:
                    .int(i)
                }
            case let .string(s):
                .string(s)
            }
        }

        var description: String {
            switch self {
            case .void: return "void"
            case let .int(v): return "int(\(v))"
            case let .int8(v): return "int8(\(v))"
            case let .int32(v): return "int32(\(v))"
            case let .bool(v): return "bool(\(v))"
            case let .string(s): return "string(\(s))"
            case let .pointer(a): return "ptr(\(a))"
            case let .structValue(f): return "struct(\(f.keys.sorted().joined(separator: ",")))"
            }
        }
    }

    // Memory address within an allocation and nested field path
    private struct Address: CustomStringConvertible, Hashable {
        let root: ObjectIdentifier // allocation root (AllocaInst)
        let path: [String] // nested field names
        var description: String { "\(root)-\(path.joined(separator: "."))" }
    }

    // Root allocation storage
    private final class Storage {
        var value: Value
        init(_ v: Value) { value = v }
    }

    private var functions: [String: NIRFunction]
    private let builtins: BuiltinRegistry

    public init(functions: [NIRFunction], builtins: BuiltinRegistry = BuiltinRegistry()) {
        self.functions = Dictionary(uniqueKeysWithValues: functions.map { ($0.name, $0) })
        self.builtins = builtins
    }

    // MARK: - Public API

    public func run(function name: String, arguments: [BuiltinValue] = []) throws -> BuiltinValue {
        // First try regular functions
        if let fn = functions[name] {
            return try run(fn, arguments: arguments)
        }
        // Then try builtin functions
        else if let builtin = builtins.get(name) {
            return try builtin(arguments)
        } else {
            throw Error.unknownFunction(name)
        }
    }

    public func run(_ function: NIRFunction, arguments: [BuiltinValue] = []) throws -> BuiltinValue {
        var ctx = ExecutionContext(functions: functions, builtins: builtins)
        // Map entry parameters
        guard function.parameters.count == arguments.count else {
            throw Error.invalidArgumentCount(expected: function.parameters.count, got: arguments.count)
        }
        for (param, arg) in zip(function.parameters, arguments) {
            ctx.bind(param, value: ctx.fromBuiltin(arg))
        }
        // Execute CFG
        return try ctx.execute(function)
    }

    // MARK: - Execution Context

    private final class ExecutionContext {
        var functions: [String: NIRFunction]
        var builtins: BuiltinRegistry
        // Value environment: NIRValue identity -> concrete Value
        var env: [ObjectIdentifier: Value] = [:]
        // Memory: root allocation id -> storage
        var memory: [ObjectIdentifier: Storage] = [:]

        init(functions: [String: NIRFunction], builtins: BuiltinRegistry) {
            self.functions = functions
            self.builtins = builtins
        }

        func bind(_ nir: any NIRValue, value: Value) {
            env[ObjectIdentifier(nir)] = value
        }

        func lookup(_ nir: any NIRValue) throws -> Value {
            if let c = nir as? Constant {
                return .init(c)
            }
            if let v = env[ObjectIdentifier(nir)] {
                return v
            }
            throw Error.missingValue("\(type(of: nir))")
        }

        func execute(_ function: NIRFunction) throws -> BuiltinValue {
            var current = function.entryBlock

            while true {
                // Evaluate instructions in order
                for inst in current.instructions {
                    let v = try eval(inst)
                    // Only bind if instruction produces a non-void value
                    if !(inst.type is VoidType) {
                        bind(inst, value: v)
                    }
                }

                // Evaluate terminator
                guard let term = current.terminator else {
                    throw Error.missingValue("Block without terminator: \(current.name)")
                }

                switch term {
                case let j as JumpTerm:
                    let values = try j.arguments.map { try lookup($0) }
                    // Map to target parameters
                    for (param, v) in zip(j.target.parameters, values) {
                        bind(param, value: v)
                    }
                    current = j.target
                    continue

                case let b as BranchTerm:
                    let condV = try lookup(b.condition)
                    guard case let .bool(cond) = condV else {
                        throw Error.typeMismatch("branch condition is not Bool")
                    }
                    if cond {
                        for (param, v) in try zip(b.trueTarget.parameters, b.trueArguments.map { try lookup($0) }) {
                            bind(param, value: v)
                        }
                        current = b.trueTarget
                    } else {
                        for (param, v) in try zip(b.falseTarget.parameters, b.falseArguments.map { try lookup($0) }) {
                            bind(param, value: v)
                        }
                        current = b.falseTarget
                    }
                    continue

                case let r as ReturnTerm:
                    if let vRef = r.value {
                        let v = try lookup(vRef)
                        return try toBuiltin(v)
                    } else {
                        return .void
                    }

                default:
                    throw Error.missingValue("Unknown terminator: \(type(of: term))")
                }
            }
        }

        // MARK: Instruction evaluation

        func eval(_ inst: any NIRInstruction) throws -> Value {
            switch inst {
            case let a as AllocaInst:
                // Allocate default storage for the allocated type
                let id = ObjectIdentifier(a)
                let initial = defaultValue(for: a.allocatedType)
                memory[id] = Storage(initial)
                return .pointer(Address(root: id, path: []))

            case let l as LoadInst:
                let addrV = try lookup(l.address)
                guard case let .pointer(addr) = addrV else { throw Error.typeMismatch("load from non-pointer") }
                return try load(at: addr)

            case let s as StoreInst:
                let addrV = try lookup(s.address)
                let valV = try lookup(s.value)
                guard case let .pointer(addr) = addrV else { throw Error.typeMismatch("store to non-pointer") }
                try store(valV, at: addr)
                return .void

            case let b as BinaryOp:
                let l = try lookup(b.left)
                let r = try lookup(b.right)
                return try evalBinary(b.operator, l, r)

            case let u as UnaryOp:
                let v = try lookup(u.operand)
                return try evalUnary(u.operator, v)

            case let c as CastInst:
                let v = try lookup(c.value)
                return try cast(v, to: c.targetType)

            case let e as FieldExtractInst:
                let base = try lookup(e.base)
                guard case let .structValue(fields) = base, let v = fields[e.fieldName] else {
                    throw Error.typeMismatch("field extract on non-struct or missing field \(e.fieldName)")
                }
                return v

            case let a as FieldAddressInst:
                let baseV = try lookup(a.baseAddress)
                guard case let .pointer(baseAddr) = baseV else { throw Error.typeMismatch("field address base is not a pointer") }
                return .pointer(Address(root: baseAddr.root, path: baseAddr.path + a.fieldPath))

            case let call as CallInst:
                // First try to find a regular function
                if let callee = functions[call.function] {
                    // Regular function call
                    let args = try call.arguments.map { try toBuiltin(lookup($0)) }
                    let child = NIRInterpreter(functions: Array(functions.values), builtins: builtins)
                    return try fromBuiltin(child.run(callee, arguments: args))
                } else if let builtin = builtins.get(call.function) {
                    // Builtin function call
                    let args = try call.arguments.map { try toBuiltin(lookup($0)) }
                    let result = try builtin(args)
                    return try fromBuiltin(result)
                } else {
                    throw Error.unknownFunction(call.function)
                }

            default:
                throw Error.missingValue("Unknown instruction: \(type(of: inst))")
            }
        }

        // MARK: - Helpers

        private func load(at address: Address) throws -> Value {
            guard let storage = memory[address.root] else { throw Error.invalidPointer }
            return try load(from: &storage.value, path: address.path[...])
        }

        private func load(from value: inout Value, path: ArraySlice<String>) throws -> Value {
            if path.isEmpty { return value }
            guard case var .structValue(fields) = value else { throw Error.typeMismatch("load path into non-struct") }
            guard let first = path.first, let field = fields[first] else { throw Error.missingValue("field \(path.first ?? "?")") }
            // Recurse without mutating original
            var tmp = field
            return try load(from: &tmp, path: path.dropFirst())
        }

        private func store(_ newValue: Value, at address: Address) throws {
            guard let storage = memory[address.root] else { throw Error.invalidPointer }
            try store(into: &storage.value, path: address.path[...], newValue: newValue)
        }

        private func store(into value: inout Value, path: ArraySlice<String>, newValue: Value) throws {
            if path.isEmpty {
                value = newValue
                return
            }
            guard case var .structValue(fields) = value else { throw Error.typeMismatch("store path into non-struct") }
            guard let first = path.first else { return }
            var sub = fields[first] ?? .void
            try store(into: &sub, path: path.dropFirst(), newValue: newValue)
            fields[first] = sub
            value = .structValue(fields)
        }

        private func evalUnary(_ op: UnaryOp.Operator, _ v: Value) throws -> Value {
            switch op {
            case .negate:
                switch v {
                case let .int(a): return .int(-a)
                case let .int32(a): return .int32(-a)
                case let .int8(a): return .int8(-a)
                default: throw Error.typeMismatch("unary - on \(v)")
                }
            case .logicalNot:
                guard case let .bool(a) = v else { throw Error.typeMismatch("! on non-bool") }
                return .bool(!a)
            }
        }

        private func evalBinary(_ op: BinaryOp.Operator, _ lv: Value, _ rv: Value) throws -> Value {
            // helper extract ints as Int64 for arithmetic, but keep width
            func binInt<T: BinaryInteger>(_ l: T, _ r: T, _ f: (T, T) -> T) -> T { f(l, r) }
            switch op {
            case .add:
                switch (lv, rv) {
                case let (.int(a), .int(b)): return .int(a + b)
                case let (.int32(a), .int32(b)): return .int32(a + b)
                case let (.int8(a), .int8(b)): return .int8(a &+ b)
                default: throw Error.typeMismatch("+ between \(lv) and \(rv)")
                }
            case .subtract:
                switch (lv, rv) {
                case let (.int(a), .int(b)): return .int(a - b)
                case let (.int32(a), .int32(b)): return .int32(a - b)
                case let (.int8(a), .int8(b)): return .int8(a &- b)
                default: throw Error.typeMismatch("- between \(lv) and \(rv)")
                }
            case .multiply:
                switch (lv, rv) {
                case let (.int(a), .int(b)): return .int(a * b)
                case let (.int32(a), .int32(b)): return .int32(a * b)
                case let (.int8(a), .int8(b)): return .int8(a &* b)
                default: throw Error.typeMismatch("* between \(lv) and \(rv)")
                }
            case .divide:
                switch (lv, rv) {
                case let (.int(a), .int(b)): return .int(a / b)
                case let (.int32(a), .int32(b)): return .int32(a / b)
                case let (.int8(a), .int8(b)): return .int8(a / b)
                default: throw Error.typeMismatch("/ between \(lv) and \(rv)")
                }
            case .modulo:
                switch (lv, rv) {
                case let (.int(a), .int(b)): return .int(a % b)
                case let (.int32(a), .int32(b)): return .int32(a % b)
                case let (.int8(a), .int8(b)): return .int8(a % b)
                default: throw Error.typeMismatch("% between \(lv) and \(rv)")
                }
            case .equal:
                switch (lv, rv) {
                case let (.int(a), .int(b)): return .bool(a == b)
                case let (.int32(a), .int32(b)): return .bool(a == b)
                case let (.int8(a), .int8(b)): return .bool(a == b)
                case let (.bool(a), .bool(b)): return .bool(a == b)
                case let (.string(a), .string(b)): return .bool(a == b)
                default: throw Error.typeMismatch("== between \(lv) and \(rv)")
                }
            case .notEqual:
                switch (lv, rv) {
                case let (.int(a), .int(b)): return .bool(a != b)
                case let (.int32(a), .int32(b)): return .bool(a != b)
                case let (.int8(a), .int8(b)): return .bool(a != b)
                case let (.bool(a), .bool(b)): return .bool(a != b)
                case let (.string(a), .string(b)): return .bool(a != b)
                default: throw Error.typeMismatch("!= between \(lv) and \(rv)")
                }
            case .lessThan:
                switch (lv, rv) {
                case let (.int(a), .int(b)): return .bool(a < b)
                case let (.int32(a), .int32(b)): return .bool(a < b)
                case let (.int8(a), .int8(b)): return .bool(a < b)
                case let (.string(a), .string(b)): return .bool(a < b)
                default: throw Error.typeMismatch("< between \(lv) and \(rv)")
                }
            case .lessThanOrEqual:
                switch (lv, rv) {
                case let (.int(a), .int(b)): return .bool(a <= b)
                case let (.int32(a), .int32(b)): return .bool(a <= b)
                case let (.int8(a), .int8(b)): return .bool(a <= b)
                case let (.string(a), .string(b)): return .bool(a <= b)
                default: throw Error.typeMismatch("<= between \(lv) and \(rv)")
                }
            case .greaterThan:
                switch (lv, rv) {
                case let (.int(a), .int(b)): return .bool(a > b)
                case let (.int32(a), .int32(b)): return .bool(a > b)
                case let (.int8(a), .int8(b)): return .bool(a > b)
                case let (.string(a), .string(b)): return .bool(a > b)
                default: throw Error.typeMismatch("> between \(lv) and \(rv)")
                }
            case .greaterThanOrEqual:
                switch (lv, rv) {
                case let (.int(a), .int(b)): return .bool(a >= b)
                case let (.int32(a), .int32(b)): return .bool(a >= b)
                case let (.int8(a), .int8(b)): return .bool(a >= b)
                case let (.string(a), .string(b)): return .bool(a >= b)
                default: throw Error.typeMismatch(">= between \(lv) and \(rv)")
                }
            case .logicalAnd, .logicalOr:
                // Short-circuiting should already be lowered to branches; handle anyway
                guard case let .bool(a) = lv, case let .bool(b) = rv else { throw Error.typeMismatch("logical op on non-bool") }
                return .bool(op == .logicalAnd ? (a && b) : (a || b))
            }
        }

        // no shared compare helper; handle per-type in evalBinary

        private func cast(_ v: Value, to target: any TypeProtocol) throws -> Value {
            switch target {
            case is IntType:
                switch v {
                case let .int(a): return .int(a)
                case let .int32(a): return .int(Int(a))
                case let .int8(a): return .int(Int(a))
                default: break
                }
            case is Int32Type:
                switch v {
                case let .int(a): return .int32(Int32(a))
                case let .int32(a): return .int32(a)
                case let .int8(a): return .int32(Int32(a))
                default: break
                }
            case is Int8Type:
                switch v {
                case let .int(a): return .int8(Int8(truncatingIfNeeded: a))
                case let .int32(a): return .int8(Int8(truncatingIfNeeded: a))
                case let .int8(a): return .int8(a)
                default: break
                }
            case is BoolType:
                switch v {
                case let .bool(b): return .bool(b)
                default: break
                }
            case let p as PointerType:
                if p.pointee is Int8Type, case let .string(string) = v {
                    return .string(string)
                }
            default:
                break
            }
            throw Error.typeMismatch("cannot cast \(v) to \(target)")
        }

        private func defaultValue(for type: any TypeProtocol) -> Value {
            switch type {
            case is IntType: return .int(0)
            case is Int32Type: return .int32(0)
            case is Int8Type: return .int8(0)
            case is BoolType: return .bool(false)
            case let s as StructType:
                var fields: [String: Value] = [:]
                for (name, t) in s.fields {
                    fields[name] = defaultValue(for: t)
                }
                return .structValue(fields)
            case let p as PointerType:
                // Uninitialized pointer; represent as void. Will error if dereferenced.
                if p.pointee is Int8Type {
                    return .string("")
                }
                return .void
            default:
                return .void
            }
        }

        // Convert between internal values and public BuiltinValue
        func toBuiltin(_ v: Value) throws -> BuiltinValue {
            switch v {
            case .void: return .void
            case let .int(i): return .int(i)
            case let .int32(i): return .int32(i)
            case let .int8(i): return .int8(i)
            case let .bool(b): return .bool(b)
            case let .string(s): return .string(s)
            case .pointer(_), .structValue:
                throw Error.typeMismatch("Return value \(v) is not a builtin value")
            }
        }

        func fromBuiltin(_ v: BuiltinValue) -> Value {
            switch v {
            case .void: return .void
            case let .int(i): return .int(i)
            case let .int8(i): return .int8(i)
            case let .int32(i): return .int32(i)
            case let .bool(b): return .bool(b)
            case let .string(s): return .string(s)
            }
        }
    }
}
