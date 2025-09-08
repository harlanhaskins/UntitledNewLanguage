import Foundation
import SSA
import Lexer
import Parser
import TypeSystem

public func runSSADemo() {
    print("=== SSA LOWERING DEMO ===\n")
    
    // Create a simple NewLang program in code
    let simpleProgram = """
    func add(_ x: Int, _ y: Int) -> Int {
        return x + y
    }
    
    func testLocalVar(_ x: Int) -> Int {
        var result: Int = x
        result = result + 1  
        return result
    }
    """
    
    do {
        // Lex and parse the program
        let lexer = Lexer(source: simpleProgram)
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
            return
        }
        
        // Lower AST to SSA
        let ssaBuilder = SSABuilder()
        let ssaFunctions = ssaBuilder.lower(declarations: ast)
        
        // Print each SSA function
        for function in ssaFunctions {
            print("\(SSAPrinter.printFunction(function))")
        }
        
    } catch {
        print("Failed to parse program: \(error)")
    }
}