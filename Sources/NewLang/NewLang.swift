import Foundation
import Lexer

@main
struct Main {
    static func main() {
        // Get the path to Test.new relative to this file
        let currentFile = #filePath
        let currentDir = URL(fileURLWithPath: currentFile).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let testFile = currentDir.appendingPathComponent("Examples/Test.new")

        do {
            let source = try String(contentsOf: testFile, encoding: .utf8)
            print("Source code:")
            print(source)
            print("\nTokens:")

            let lexer = Lexer(source: source)
            let tokens = lexer.tokenize()

            for token in tokens {
                print("\(token.range): \(token.kind)")
            }
        } catch {
            print("Error reading file: \(error)")
        }
    }
}
