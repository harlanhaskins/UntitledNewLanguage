/// Severity levels for diagnostics
public enum DiagnosticSeverity {
    case error
    case warning
    case note
}

/// A diagnostic message with location and severity
public struct Diagnostic {
    public let range: SourceRange
    public let severity: DiagnosticSeverity
    public let message: String
    public let category: String?

    public init(range: SourceRange, severity: DiagnosticSeverity, message: String, category: String? = nil) {
        self.range = range
        self.severity = severity
        self.message = message
        self.category = category
    }
}

extension Diagnostic: CustomStringConvertible {
    public var description: String {
        let severityStr = switch severity {
        case .error: "error"
        case .warning: "warning"
        case .note: "note"
        }

        if let category = category {
            return "\(range): \(severityStr) [\(category)]: \(message)"
        } else {
            return "\(range): \(severityStr): \(message)"
        }
    }
}

/// Engine for collecting and managing diagnostics during compilation
public final class DiagnosticEngine {
    private var diagnostics: [Diagnostic] = []

    public init() {}

    /// Report an error diagnostic
    public func error(at range: SourceRange, message: String, category: String? = nil) {
        diagnostics.append(Diagnostic(range: range, severity: .error, message: message, category: category))
    }

    /// Report a warning diagnostic
    public func warning(at range: SourceRange, message: String, category: String? = nil) {
        diagnostics.append(Diagnostic(range: range, severity: .warning, message: message, category: category))
    }

    /// Report a note diagnostic
    public func note(at range: SourceRange, message: String, category: String? = nil) {
        diagnostics.append(Diagnostic(range: range, severity: .note, message: message, category: category))
    }

    /// Get all collected diagnostics
    public var allDiagnostics: [Diagnostic] {
        return diagnostics
    }

    /// Get only error diagnostics
    public var errors: [Diagnostic] {
        return diagnostics.filter { $0.severity == .error }
    }

    /// Get only warning diagnostics
    public var warnings: [Diagnostic] {
        return diagnostics.filter { $0.severity == .warning }
    }

    /// Check if there are any errors
    public var hasErrors: Bool {
        return diagnostics.contains { $0.severity == .error }
    }

    /// Check if there are any warnings
    public var hasWarnings: Bool {
        return diagnostics.contains { $0.severity == .warning }
    }

    /// Clear all diagnostics
    public func clear() {
        diagnostics.removeAll()
    }

    /// Get count of diagnostics by severity
    public var errorCount: Int {
        return errors.count
    }

    public var warningCount: Int {
        return warnings.count
    }

    /// Format diagnostics for display
    public func formatDiagnostics() -> String {
        if diagnostics.isEmpty {
            return "No diagnostics"
        }

        return diagnostics.map(\.description).joined(separator: "\n")
    }
}

// MARK: - SSA Analysis Diagnostic Extensions

/// Enum for unused variable kinds
public enum UnusedVariableKind {
    case uninitialized
    case writeOnly(storeCount: Int)
}

public extension DiagnosticEngine {
    /// SSA analysis specific diagnostic methods

    func unusedVariable(function: String, type: String, kind: UnusedVariableKind) {
        let defaultRange = SourceRange(start: SourceLocation(line: 0, column: 0, offset: 0), end: SourceLocation(line: 0, column: 0, offset: 0))

        switch kind {
        case .uninitialized:
            warning(at: defaultRange, message: "unused variable of type '\(type)' in function '\(function)' (allocated but never used)", category: "ssa-analysis")
        case let .writeOnly(storeCount):
            warning(at: defaultRange, message: "unused variable of type '\(type)' in function '\(function)' (written \(storeCount) time\(storeCount == 1 ? "" : "s") but never read)", category: "ssa-analysis")
        }
    }

    func unusedVariableSummary(function: String, totalUnused: Int, uninitialized: Int, writeOnly: Int) {
        let defaultRange = SourceRange(start: SourceLocation(line: 0, column: 0, offset: 0), end: SourceLocation(line: 0, column: 0, offset: 0))

        var summary = "Function '\(function)': \(totalUnused) unused variable\(totalUnused == 1 ? "" : "s")"
        if uninitialized > 0, writeOnly > 0 {
            summary += " (\(uninitialized) uninitialized, \(writeOnly) write-only)"
        } else if uninitialized > 0 {
            summary += " (all uninitialized)"
        } else if writeOnly > 0 {
            summary += " (all write-only)"
        }

        note(at: defaultRange, message: summary, category: "ssa-analysis")
    }
}
