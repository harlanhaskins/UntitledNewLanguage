import Foundation
import CompilerDriver

@main
struct Main {
    static func main() async {
        let args = CommandLine.arguments

        // If no arguments provided, use the default test file
        let inputFile: String
        var outputFile: String?

        if args.count < 2 {
            // Get the path to Test.new relative to this file
            let currentFile = #filePath
            let currentDir = URL(fileURLWithPath: currentFile).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            inputFile = currentDir.appendingPathComponent("Examples/Test.new").path
            outputFile = "test_program"
        } else {
            inputFile = args[1]
            if args.count > 2 {
                outputFile = args[2]
            }
        }

        do {
            let compiler = CompilerDriver()
            try await compiler.compile(inputFile: inputFile, outputFile: outputFile)
        } catch {
            print("Compilation failed: \(error)")
            exit(1)
        }
    }
}
