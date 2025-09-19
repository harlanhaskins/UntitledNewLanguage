# NIRInterpreter Builtin Function Registry

The NIRInterpreter now supports a registry of builtin functions that clients can provide. This allows external code to register Swift closures that can be called from interpreted NewLang code.

## Overview

Instead of only supporting hardcoded NIR functions, the interpreter can now call into client-provided Swift functions through a type-safe registry system.

## Key Components

### `BuiltinValue` Enum
Represents values that can be passed between interpreted code and builtin functions:
- `.void` - No value
- `.int(Int)` - Integer value  
- `.int8(Int8)` - 8-bit integer
- `.int32(Int32)` - 32-bit integer
- `.bool(Bool)` - Boolean value
- `.string(String)` - String value

### `BuiltinFunction` Type Alias
```swift
public typealias BuiltinFunction = ([BuiltinValue]) throws -> BuiltinValue
```

### `BuiltinRegistry` Class
Manages the registration and lookup of builtin functions:
- `register(_ name: String, function: @escaping BuiltinFunction)` - Register a function
- `unregister(_ name: String)` - Remove a function
- `contains(_ name: String) -> Bool` - Check if function exists
- `registeredNames: [String]` - Get all registered function names

## Usage Example

```swift
import Driver
import NIR

// Create interpreter driver
let driver = InterpreterDriver()

// Register a simple print function
driver.builtins.register("print") { args in
    let output = args.map { $0.description }.joined(separator: " ")
    print(output)
    return .void
}

// Register a math function  
driver.builtins.register("add") { args in
    guard args.count == 2 else {
        throw NIRInterpreter.Error.invalidArgumentCount(expected: 2, got: args.count)
    }
    
    guard case let .int32(a) = args[0], case let .int32(b) = args[1] else {
        throw NIRInterpreter.Error.typeMismatch("add requires two int32 arguments")
    }
    
    return .int32(a + b)
}

// NewLang code that uses the builtins
let sourceCode = """
func main() -> Int32 {
    print("Hello from builtin!")
    return add(10, 20)
}
"""

// Interpret the code
let result = try driver.interpret(sourceCode: sourceCode)
print("Result: \\(result)") // Prints: Result: 30
```

## Function Resolution Order

When the interpreter encounters a function call, it searches in this order:
1. Regular NIR functions (defined in the NewLang source)
2. Builtin functions (registered in the registry)
3. If not found, throws `Error.unknownFunction`

## Error Handling

Builtin functions can throw these errors:
- `NIRInterpreter.Error.invalidArgumentCount(expected:got:)` - Wrong number of arguments
- `NIRInterpreter.Error.typeMismatch(_)` - Type mismatch in arguments or return value  
- Any other Swift error (will be propagated)

## Integration Points

The builtin registry integrates seamlessly with:
- `NIRInterpreter` - Core interpreter with builtin support
- `InterpreterDriver` - High-level driver with builtin registry access
- Existing NIR function calls - No changes to existing interpreted code

## API Design

The API follows Swift best practices:
- Type-safe value representation with `BuiltinValue` enum
- Error handling through Swift's error system  
- Closure-based function registration for flexibility
- Optional registry parameter with sensible defaults
- Convenience methods for easy access (`driver.builtins`)

This design enables powerful extensibility while maintaining type safety and performance.