//
//  DiagnosticEngine+TypeChecker.swift
//  NewLang
//
//  Created by Harlan Haskins on 9/8/25.
//

import Base
import Types

// MARK: - Type Checking Diagnostic Extensions

public extension DiagnosticEngine {
    /// Type checking specific diagnostic methods

    func unknownType(at range: SourceRange, name: String) {
        error(at: range, message: "unknown type '\(name)'", category: "type-checker")
    }

    func undefinedVariable(at range: SourceRange, name: String) {
        error(at: range, message: "undefined variable '\(name)'", category: "type-checker")
    }

    func argumentCountMismatch(at range: SourceRange, expected: Int, actual: Int) {
        error(at: range, message: "argument count mismatch - expected \(expected), got \(actual)", category: "type-checker")
    }

    func notCallable(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "type '\(type)' is not callable", category: "type-checker")
    }

    func invalidOperation(at range: SourceRange, operation: String, type: any TypeProtocol) {
        error(at: range, message: "invalid operation '\(operation)' on type '\(type)'", category: "type-checker")
    }

    func variadicArgumentType(at range: SourceRange, type: any TypeProtocol) {
        note(at: range, message: "variadic argument of type '\(type)'", category: "type-checker")
    }

    func typeMismatch(at range: SourceRange, expected: any TypeProtocol, actual: any TypeProtocol) {
        error(at: range, message: "type mismatch - expected '\(expected)', got '\(actual)'", category: "type-checker")
    }

    func missingInitializer(at range: SourceRange, name: String) {
        error(at: range, message: "variable '\(name)' requires an initializer", category: "type-checker")
    }

    func missingFieldType(at range: SourceRange, name: String) {
        error(at: range, message: "field '\(name)' requires an explicit type", category: "type-checker")
    }

    func invalidMemberAccess(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "type '\(type)' has no members", category: "type-checker")
    }

    func unknownMember(at range: SourceRange, type: any TypeProtocol, member: String) {
        error(at: range, message: "type '\(type)' has no member '\(member)'", category: "type-checker")
    }
}
