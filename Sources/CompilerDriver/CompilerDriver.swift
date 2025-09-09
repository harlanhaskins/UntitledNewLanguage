import Base
import Foundation
import Lexer
import Parser
import SSA
import Subprocess
import TypeSystem

/// Configuration options for the compiler
public struct CompilerOptions {
    public let verbose: Bool
    public let skipAnalysis: Bool
    public let analyzeOnly: Bool
    public let emitSsa: Bool
    public let emitC: Bool

    public init(verbose: Bool = false, skipAnalysis: Bool = false, analyzeOnly: Bool = false, emitSsa: Bool = false, emitC: Bool = false) {
        self.verbose = verbose
        self.skipAnalysis = skipAnalysis
        self.analyzeOnly = analyzeOnly
        self.emitSsa = emitSsa
        self.emitC = emitC
    }
}

public final class CompilerDriver {
    private let options: CompilerOptions

    public init(options: CompilerOptions = CompilerOptions()) {
        self.options = options
    }

    public func compile(inputFile: URL, outputFile: URL) async throws {
        if !options.verbose && !options.emitC && !options.emitSsa {
            print("=== NEWLANG COMPILER ===")
        }

        // Step 1: Read source code
        let sourceCode = try String(contentsOf: inputFile, encoding: .utf8)
        if options.verbose {
            print("Reading source file: \(inputFile.path)")
        }

        // Step 2: Lex the source code
        if options.verbose { print("Step 2: Lexical analysis") }
        let lexer = Lexer(source: sourceCode)
        let tokens = lexer.tokenize()

        // Step 3: Parse the tokens
        if options.verbose { print("Step 3: Parsing") }
        let parser = Parser(tokens: tokens)
        let ast = try parser.parse()

        // Step 4: Type check the AST
        if options.verbose { print("Step 4: Type checking") }
        let diagnostics = DiagnosticEngine()
        let typeChecker = TypeChecker(diagnostics: diagnostics)
        typeChecker.typeCheck(declarations: ast)

        if diagnostics.hasErrors {
            for error in diagnostics.errors {
                print("Error: \(error)")
            }
            throw CompilerError.typeCheckingFailed
        }

        // Step 5: Lower AST to SSA
        if options.verbose { print("Step 5: Lowering to SSA") }
        let ssaBuilder = SSABuilder()
        var ssaFunctions = ssaBuilder.lower(declarations: ast)

        // Step 5a: Run SSA passes for analysis and optimization
        if !options.skipAnalysis {
            if options.verbose { print("Step 5a: Running SSA analysis passes") }

            let passManager = SSAFunctionPassManager()
            let ssaDiagnostics = DiagnosticEngine()

            // Run unused variable analysis pass
            let unusedVarPass = UnusedVariableFunctionPass()
            passManager.runAnalysisOnAllFunctions(unusedVarPass, on: &ssaFunctions, diagnostics: ssaDiagnostics)

            // Run dead code elimination pass
            let deadCodePass = DeadCodeEliminationPass()
            passManager.runTransformOnAllFunctions(deadCodePass, on: &ssaFunctions)

            // Report analysis results
            if !options.emitC && !options.emitSsa {
                if ssaDiagnostics.hasWarnings {
                    for warning in ssaDiagnostics.warnings {
                        print("Warning: \(warning.message)")
                    }
                    for note in ssaDiagnostics.allDiagnostics.filter({ $0.severity == .note }) {
                        print("Note: \(note.message)")
                    }
                } else {
                    print("✅ No unused variables detected.")
                }
            }
        }

        // If emit-ssa mode, output SSA and exit
        if options.emitSsa {
            for function in ssaFunctions {
                print(SSAPrinter.printFunction(function))
            }
            return
        }

        // If analyze-only mode, stop here
        if options.analyzeOnly {
            if options.verbose { print("Analysis complete. Skipping code generation.") }
            return
        }

        // Step 6: Generate C code from SSA
        if options.verbose { print("Step 6: Generating C code") }

        // Generate extern declarations and headers first
        var cCode = SSAToCLowering.generateExternDeclarations(ast)

        // Generate function definitions
        for function in ssaFunctions {
            cCode += SSAToCLowering.lowerFunction(function)
            cCode += "\n"
        }

        // If emit-c mode, output C code and exit
        if options.emitC {
            print(cCode)
            return
        }

        if options.verbose {
            print("Generated C code")
            print(cCode)
        }

        // Step 7: Write C code to temporary file
        let tempCFile = URL(filePath: "/tmp/\(UUID().uuidString).c")
        try cCode.write(to: tempCFile, atomically: true, encoding: String.Encoding.utf8)

        if options.verbose {
            print("Step 7: Writing temporary C file to \(tempCFile.path)")
        }

        // Step 8: Compile C code with clang
        if options.verbose { print("Step 8: Compiling C to executable") }
        else { print("Compiling to executable...") }
        try await compileWithClang(cFile: tempCFile, outputFile: outputFile)

        // Step 9: Clean up temp file
        try FileManager.default.removeItem(at: tempCFile)

        if options.verbose {
            print("Step 9: Cleaned up temporary files")
            print("✅ Compilation successful! Output: \(outputFile.path)")
        } else {
            print("✅ Compilation successful! Output: \(outputFile.path)")
        }
    }

    private func compileWithClang(cFile: URL, outputFile: URL) async throws {
        let result = try await Subprocess.run(
            .name("clang"),
            arguments: [
                "-o", outputFile.path,
                cFile.path,
                "-std=c99",
                "-Wall",
            ],
            output: .string(limit: 2048, encoding: UTF8.self),
            error: .string(limit: 2048, encoding: UTF8.self)
        )

        if result.terminationStatus != .exited(0) {
            throw CompilerError.clangFailed(result.standardError ?? "")
        }
    }
}

public enum CompilerError: Error, CustomStringConvertible {
    case clangFailed(String)
    case fileNotFound(String)
    case typeCheckingFailed

    public var description: String {
        switch self {
        case let .clangFailed(stderr):
            return "Clang compilation failed:\n\(stderr)"
        case let .fileNotFound(path):
            return "File not found: \(path)"
        case .typeCheckingFailed:
            return "Type checking failed"
        }
    }
}
