import AST
import Base
import Foundation
import Lexer
import Parser
import TypeSystem
import SSA

public final class InterpreterDriver {
    private let verbose: Bool

    public init(verbose: Bool = false) {
        self.verbose = verbose
    }

    public func interpret(inputFile: URL) throws -> SSAInterpreter.BuiltinValue {
        if verbose { print("Interpreting \(inputFile.path)") }

        // 1) Read
        let sourceCode = try String(contentsOf: inputFile, encoding: .utf8)
        return try interpret(sourceCode: sourceCode)
    }


    public func interpret(sourceCode: String) throws -> SSAInterpreter.BuiltinValue {

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
            for error in diagnostics.errors { print("Error: \(error)") }
            throw CompilerError.typeCheckingFailed
        }

        // 5) Lower to SSA
        let ssaDiagnostics = DiagnosticEngine()
        let ssaBuilder = SSABuilder(diagnostics: ssaDiagnostics)
        let ssaFunctions = ssaBuilder.lower(declarations: ast)
        if ssaDiagnostics.hasErrors {
            for error in ssaDiagnostics.errors { print("Error: \(error)") }
            throw CompilerError.loweringFailed
        }

        // 6) Interpret main
        let interpreter = SSAInterpreter(functions: ssaFunctions)
        return try interpreter.run(function: "main")
    }
}
