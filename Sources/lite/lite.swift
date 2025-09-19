import Foundation
import LiteSupport

@main
struct LiteTestRunner {
    static func main() async {
        do {
            // Get the current working directory and find the Tests directory
            let testDir = URL(filePath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Tests")
                .appendingPathComponent("lite")

            // Build the NewLang compiler binary path
            let projectDir = URL(filePath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let newLangBinary = projectDir
                .appendingPathComponent(".build")
                .appendingPathComponent("debug")
                .appendingPathComponent("NewLang")

            // Discover FileCheck binary
            let fileCheckBinary = findFileCheck()

            print("Looking for tests in: \(testDir.path)")
            print("Using NewLang binary: \(newLangBinary.path)")
            if let fileCheck = fileCheckBinary {
                print("Using FileCheck: \(fileCheck)")
            } else {
                print("Warning: FileCheck not found, FileCheck tests will fail")
            }

            var substitutions: [(String, String)] = [
                ("newlang", newLangBinary.path),
                ("NewLang", newLangBinary.path),
            ]

            if let fileCheck = fileCheckBinary {
                substitutions.append(("FileCheck", fileCheck))
            }

            let allPassed = try await runLite(
                substitutions: substitutions,
                pathExtensions: ["nl"],
                testDirPath: testDir.path,
                testLinePrefix: "//",
                parallelismLevel: .automatic,
                successMessage: "All NewLang tests passed! 🎉"
            )

            exit(allPassed ? 0 : 1)
        } catch let err as LiteError {
            fputs("error: \(err.message)\n", stderr)
            exit(1)
        } catch {
            fputs("unhandled error: \(error)\n", stderr)
            exit(1)
        }
    }

    /// Find FileCheck binary in common locations
    static func findFileCheck() -> String? {
        let commonPaths = [
            "/usr/local/bin/FileCheck",
            "/opt/homebrew/bin/FileCheck",
            "/opt/homebrew/opt/llvm/bin/FileCheck",
            "/usr/bin/FileCheck",
        ]

        // First try common paths
        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Then try to find it on PATH using `which`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["FileCheck"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty
                {
                    return path
                }
            }
        } catch {
            // If `which` fails, continue searching
        }

        return nil
    }
}
