import AST
import Base
import Foundation
import Lexer
import NIR
import Parser
import TypeSystem

public final class InterpreterDriver {
    private let verbose: Bool
    public let builtins: NIRInterpreter.BuiltinRegistry

    public init(verbose: Bool = false, builtins: NIRInterpreter.BuiltinRegistry = NIRInterpreter.BuiltinRegistry()) {
        self.verbose = verbose
        self.builtins = builtins
    }

    public func interpret(inputFile: URL) throws -> NIRInterpreter.BuiltinValue {
        if verbose { print("Interpreting \(inputFile.path)") }

        // 1) Read
        let sourceCode = try String(contentsOf: inputFile, encoding: .utf8)
        return try interpret(sourceCode: sourceCode)
    }

    public func interpret(sourceCode: String) throws -> NIRInterpreter.BuiltinValue {
        // 2) Lex
        let lexer = Lexer(source: sourceCode)
        let tokens = lexer.tokenize()

        // 3) Parse
        let parser = Parser(tokens: tokens)
        let ast: [any Declaration]
        do {
            ast = try parser.parse()
        } catch let err as ParseError {
            print(err.description)
            throw CompilerError.parseFailed(err.description)
        }

        // 4) Type check
        let diagnostics = DiagnosticEngine()
        let typeChecker = TypeChecker(diagnostics: diagnostics)
        typeChecker.typeCheck(declarations: ast)
        if diagnostics.hasErrors {
            for error in diagnostics.errors {
                print("Error: \(error)")
            }
            throw CompilerError.typeCheckingFailed
        }

        // 5) Lower to NIR
        let nirDiagnostics = DiagnosticEngine()
        let nirBuilder = NIRBuilder(diagnostics: nirDiagnostics)
        let nirFunctions = nirBuilder.lower(declarations: ast)
        if nirDiagnostics.hasErrors {
            for error in nirDiagnostics.errors {
                print("Error: \(error)")
            }
            throw CompilerError.loweringFailed
        }

        // 6) Interpret main
        let interpreter = NIRInterpreter(functions: nirFunctions, builtins: builtins)
        return try interpreter.run(function: "main")
    }
}
