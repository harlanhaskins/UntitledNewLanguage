import Foundation
import Base
import Lexer
import Parser
import AST
import TypeSystem
import NIR

public struct PipelineOptions: Sendable {
    public var optimize: Bool
    public var runAnalysisPasses: Bool
    public var verbose: Bool

    public init(optimize: Bool = false, runAnalysisPasses: Bool = true, verbose: Bool = false) {
        self.optimize = optimize
        self.runAnalysisPasses = runAnalysisPasses
        self.verbose = verbose
    }
}

public enum PipelineStage: String, Sendable {
    case tokens
    case ast
    case typeChecked
    case nir
    case c
}

public struct PipelineResult {
    public var tokens: [Token]? = nil
    public var ast: [any Declaration]? = nil
    public var typeDiagnostics: DiagnosticEngine? = nil
    public var nirFunctions: [NIRFunction]? = nil
    public var nirDiagnostics: DiagnosticEngine? = nil
    public var cCode: String? = nil
}

/// High-level orchestrator for running the compiler pipeline and retrieving
/// intermediate artifacts for integration in applications.
public enum PipelineRunner {
    public static func runFile(_ url: URL, upTo stage: PipelineStage, options: PipelineOptions = PipelineOptions()) throws -> PipelineResult {
        let source = try String(contentsOf: url, encoding: .utf8)
        return try runSource(source, upTo: stage, options: options)
    }

    public static func runSource(_ source: String, upTo stage: PipelineStage, options: PipelineOptions = PipelineOptions()) throws -> PipelineResult {
        var result = PipelineResult()

        // Lex
        if options.verbose { print("[pipeline] lexing…") }
        let lexer = Lexer(source: source)
        let tokens = lexer.tokenize()
        result.tokens = tokens
        if stage == .tokens { return result }

        // Parse
        if options.verbose { print("[pipeline] parsing…") }
        let parser = Parser(tokens: tokens)
        let ast: [any Declaration]
        do {
            ast = try parser.parse()
        } catch let err as ParseError {
            throw CompilerError.parseFailed(err.description)
        }
        result.ast = ast
        if stage == .ast { return result }

        // Type check
        if options.verbose { print("[pipeline] type checking…") }
        let typeDiagnostics = DiagnosticEngine()
        let typeChecker = TypeChecker(diagnostics: typeDiagnostics)
        typeChecker.typeCheck(declarations: ast)
        result.typeDiagnostics = typeDiagnostics
        if stage == .typeChecked { return result }
        if typeDiagnostics.hasErrors { throw CompilerError.typeCheckingFailed }

        // Lower to NIR
        if options.verbose { print("[pipeline] lowering to NIR…") }
        let nirDiagnostics = DiagnosticEngine()
        let nirBuilder = NIRBuilder(diagnostics: nirDiagnostics)
        var functions = nirBuilder.lower(declarations: ast)
        result.nirDiagnostics = nirDiagnostics
        result.nirFunctions = functions
        if nirDiagnostics.hasErrors { throw CompilerError.loweringFailed }
        if stage == .nir { return result }

        // Analysis/optimization passes (optional)
        if options.runAnalysisPasses {
            if options.verbose { print("[pipeline] analysis passes…") }
            let passManager = NIRFunctionPassManager()
            // Always run dead code elimination + unused variable analysis
            let analysisDiag = DiagnosticEngine()
            let unusedVarPass = UnusedVariableFunctionPass()
            passManager.runAnalysisOnAllFunctions(unusedVarPass, on: &functions, diagnostics: analysisDiag)
            let dce = DeadCodeEliminationPass()
            passManager.runTransformOnAllFunctions(dce, on: &functions)
            result.nirFunctions = functions
        }

        // Emit C
        if options.verbose { print("[pipeline] generating C…") }
        var emitter = CEmitter()
        // Build module C: preamble, externs, forward decls, bodies
        // Collect extern decls from the AST
        var cCode = ""
        cCode += emitter.generatePreamble()
        cCode += emitter.generateExternDeclarations(ast)
        for f in functions { emitter.addFunction(f) }
        cCode += emitter.emitModule(declarations: ast)
        result.cCode = cCode
        return result
    }
}

