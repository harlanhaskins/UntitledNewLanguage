//
//  DiagnosticEngine+TypeChecker.swift
//  NewLang
//
//  Created by Harlan Haskins on 9/8/25.
//

import Base
import Types

// MARK: - Type Checking Diagnostic Extensions

extension DiagnosticEngine {
    /// Type checking specific diagnostic methods
    
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

    public func typeMismatch(at range: SourceRange, expected: any TypeProtocol, actual: any TypeProtocol) {
        error(at: range, message: "type mismatch - expected '\(expected)', got '\(actual)'", category: "type-checker")
    }
}
