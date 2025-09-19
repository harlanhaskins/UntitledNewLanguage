// Example: How to use the NIRInterpreter builtin function registry
// This shows how clients can register custom builtin functions

import Driver
import Foundation
import NIR

func main() throws {
    // Create an interpreter driver
    let driver = InterpreterDriver(verbose: true)

    // Register some builtin functions
    driver.builtins.register("print") { args in
        // Print function that takes any number of arguments
        let output = args.map { $0.description }.joined(separator: " ")
        print(output)
        return .void
    }

    driver.builtins.register("add") { args in
        // Add function that adds two integers
        guard args.count == 2 else {
            throw NIRInterpreter.Error.invalidArgumentCount(expected: 2, got: args.count)
        }

        guard case let .int32(a) = args[0], case let .int32(b) = args[1] else {
            throw NIRInterpreter.Error.typeMismatch("add requires two int32 arguments")
        }

        return .int32(a + b)
    }

    driver.builtins.register("multiply") { args in
        // Multiply function with flexible integer types
        guard args.count == 2 else {
            throw NIRInterpreter.Error.invalidArgumentCount(expected: 2, got: args.count)
        }

        let a: Int32
        let b: Int32

        switch args[0] {
        case let .int32(val): a = val
        case let .int(val): a = Int32(val)
        case let .int8(val): a = Int32(val)
        default: throw NIRInterpreter.Error.typeMismatch("multiply requires numeric first argument")
        }

        switch args[1] {
        case let .int32(val): b = val
        case let .int(val): b = Int32(val)
        case let .int8(val): b = Int32(val)
        default: throw NIRInterpreter.Error.typeMismatch("multiply requires numeric second argument")
        }

        return .int32(a * b)
    }

    driver.builtins.register("getString") { args in
        // Function that returns a string
        guard args.isEmpty else {
            throw NIRInterpreter.Error.invalidArgumentCount(expected: 0, got: args.count)
        }
        return .string("Hello from builtin!")
    }

    driver.builtins.register("isEven") { args in
        // Function that checks if a number is even
        guard args.count == 1 else {
            throw NIRInterpreter.Error.invalidArgumentCount(expected: 1, got: args.count)
        }

        let value: Int32
        switch args[0] {
        case let .int32(val): value = val
        case let .int(val): value = Int32(val)
        case let .int8(val): value = Int32(val)
        default: throw NIRInterpreter.Error.typeMismatch("isEven requires numeric argument")
        }

        return .bool(value % 2 == 0)
    }

    // Example NewLang code that uses the builtin functions
    let sourceCode = """
    func main() -> Int32 {
        print("Testing builtin functions")

        var result = add(10, 20)
        print("10 + 20 =", result)

        var product = multiply(result, 2)
        print("Result * 2 =", product)

        var message = getString()
        print("Message:", message)

        var even = isEven(product)
        print("Is product even?", even)

        return product
    }
    """

    // Interpret the code
    do {
        let result = try driver.interpret(sourceCode: sourceCode)
        print("Final result: \\(result)")
    } catch {
        print("Error: \\(error)")
    }
}

// Run the example
try main()
