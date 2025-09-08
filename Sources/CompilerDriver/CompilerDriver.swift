import Foundation
import Lexer
import Parser  
import TypeSystem
import SSA
import Subprocess

public final class CompilerDriver {
    public init() {}
    
    public func compile(inputFile: String, outputFile: String? = nil) async throws {
        print("=== NEWLANG COMPILER ===")
        
        // Determine output file name
        let finalOutputFile = outputFile ?? inputFile.replacingOccurrences(of: ".new", with: "")
        
        // Step 1: Read source code
        let sourceCode = try String(contentsOfFile: inputFile, encoding: .utf8)
        print("Compiling: \(inputFile)")
        
        // Step 2: Lex the source code
        print("Lexing...")
        let lexer = Lexer(source: sourceCode)
        let tokens = lexer.tokenize()
        
        // Step 3: Parse the tokens
        print("Parsing...")
        let parser = Parser(tokens: tokens)
        let ast = try parser.parse()
        
        // Step 4: Type check the AST
        print("Type checking...")
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
        print("Lowering to SSA...")
        let ssaBuilder = SSABuilder()
        let ssaFunctions = ssaBuilder.lower(declarations: ast)
        
        // Step 6: Generate C code from SSA
        print("Generating C code...")
        var cCode = ""
        for function in ssaFunctions {
            cCode += SSAToCLowering.lowerFunction(function)
            cCode += "\n"
        }
        
        // Step 7: Write C code to temporary file
        let tempCFile = "/tmp/\(UUID().uuidString).c"
        try cCode.write(toFile: tempCFile, atomically: true, encoding: String.Encoding.utf8)
        
        // Step 8: Compile C code with clang
        print("Compiling to executable...")
        try await compileWithClang(cFile: tempCFile, outputFile: finalOutputFile)
        
        // Step 9: Clean up temp file
        try FileManager.default.removeItem(atPath: tempCFile)
        
        print("✅ Compilation successful! Output: \(finalOutputFile)")
    }
    
    private func compileWithClang(cFile: String, outputFile: String) async throws {
        let result = try await Subprocess.run(
            .name("clang"),
            arguments: [
                "-o", outputFile,
                cFile,
                "-std=c99",
                "-Wall"
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
        case .clangFailed(let stderr):
            return "Clang compilation failed:\n\(stderr)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .typeCheckingFailed:
            return "Type checking failed"
        }
    }
}
