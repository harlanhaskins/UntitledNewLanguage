import Foundation
import SSA
import Lexer
import Parser
import TypeSystem

public func runSSADemo() {
    print("=== SSA LOWERING DEMO ===\n")
    
    // Get Examples directory path
    let examplesPath = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Examples")

    do {
        // Read all .newlang files from Examples directory
        let fileManager = FileManager.default
        let exampleFiles = try fileManager.contentsOfDirectory(at: examplesPath, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "newlang" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        if exampleFiles.isEmpty {
            print("No .newlang files found in Examples directory")
            return
        }
        
        // Process each example file
        for fileName in exampleFiles {
            print("=== COMPILING: \(fileName) ===\n")
            
            // Read file content
            let source = try String(contentsOf: fileName, encoding: .utf8)

            // Lex and parse the program
            let lexer = Lexer(source: source)
            let tokens = lexer.tokenize()
            let parser = Parser(tokens: tokens)
            let ast = try parser.parse()
            
            // Type check the AST
            let diagnostics = DiagnosticEngine()
            let typeChecker = TypeChecker(diagnostics: diagnostics)
            typeChecker.typeCheck(declarations: ast)
            
            if diagnostics.hasErrors {
                print("Type checking failed:")
                for error in diagnostics.errors {
                    print("  \(error)")
                }
                continue
            }
            
            // Lower AST to SSA
            let ssaBuilder = SSABuilder()
            let ssaFunctions = ssaBuilder.lower(declarations: ast)
            
            if ssaFunctions.isEmpty {
                print("No functions to compile in \(fileName)")
                continue
            }
            
            // Print SSA representation
            print("SSA IR:")
            for function in ssaFunctions {
                print(SSAPrinter.printFunction(function))
            }
            
            // Generate C code
            print("Generated C code:")
            for function in ssaFunctions {
                print(SSAToCLowering.lowerFunction(function))
            }
            
            print("") // Extra line between files
        }
        
    } catch {
        print("Error reading examples: \(error)")
    }
}
