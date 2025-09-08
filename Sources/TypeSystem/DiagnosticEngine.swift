import Base
import Types

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

// MARK: - Type Checking Diagnostic Extensions

extension DiagnosticEngine {
    /// Type checking specific diagnostic methods
    
    public func typeMismatch(at range: SourceRange, expected: any TypeProtocol, actual: any TypeProtocol) {
        error(at: range, message: "type mismatch - expected '\(expected)', got '\(actual)'", category: "type-checker")
    }
    
    public func unknownType(at range: SourceRange, name: String) {
        error(at: range, message: "unknown type '\(name)'", category: "type-checker")
    }
    
    public func undefinedVariable(at range: SourceRange, name: String) {
        error(at: range, message: "undefined variable '\(name)'", category: "type-checker")
    }
    
    public func argumentCountMismatch(at range: SourceRange, expected: Int, actual: Int) {
        error(at: range, message: "argument count mismatch - expected \(expected), got \(actual)", category: "type-checker")
    }
    
    public func notCallable(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "type '\(type)' is not callable", category: "type-checker")
    }
    
    public func invalidOperation(at range: SourceRange, operation: String, type: any TypeProtocol) {
        error(at: range, message: "invalid operation '\(operation)' on type '\(type)'", category: "type-checker")
    }
    
    public func variadicArgumentType(at range: SourceRange, type: any TypeProtocol) {
        note(at: range, message: "variadic argument of type '\(type)'", category: "type-checker")
    }
}
