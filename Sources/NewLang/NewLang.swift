import Foundation
import CompilerDriver
import ArgumentParser

@main
struct NewLangCompiler: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "newlang",
        abstract: "The NewLang programming language compiler",
        discussion: """
            NewLang is a statically typed programming language that compiles to C.
            This compiler supports boolean operations, integer arithmetic, and function declarations.
            """,
        version: "0.1.0"
    )
    
    @Argument(help: "The source file to compile (.nl extension)")
    var inputFile: String
    
    @Option(name: .shortAndLong, help: "The output executable file")
    var output: String?
    
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose: Bool = false
    
    @Flag(help: "Skip SSA analysis passes")
    var skipAnalysis: Bool = false
    
    @Flag(help: "Only run analysis passes without generating executable")
    var analyzeOnly: Bool = false
    
    func validate() throws {
        // Check if input file exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: inputFile) {
            throw ValidationError("Input file '\(inputFile)' does not exist.")
        }
    }
    
    func run() async throws {
        let inputURL = URL(filePath: inputFile)
        let outputURL: URL?
        
        if let output = output {
            outputURL = URL(filePath: output)
        } else {
            // Default output: same name as input but without extension
            outputURL = inputURL.deletingPathExtension()
        }
        
        if verbose {
            print("NewLang Compiler v\(Self.configuration.version)")
            print("Input: \(inputFile)")
            if let outputURL = outputURL {
                print("Output: \(outputURL.path)")
            }
            print("Options:")
            print("  - Verbose: \(verbose)")
            print("  - Skip Analysis: \(skipAnalysis)")
            print("  - Analyze Only: \(analyzeOnly)")
            print()
        }
        
        do {
            let compilerOptions = CompilerOptions(
                verbose: verbose,
                skipAnalysis: skipAnalysis,
                analyzeOnly: analyzeOnly
            )
            let compiler = CompilerDriver(options: compilerOptions)
            try await compiler.compile(inputFile: inputURL, outputFile: outputURL)
            
            if verbose {
                print("\n✅ Compilation completed successfully!")
            }
        } catch {
            if verbose {
                print("\n❌ Compilation failed with error:")
                print(error)
            } else {
                print("Compilation failed: \(error)")
            }
            throw ExitCode.failure
        }
    }
}
