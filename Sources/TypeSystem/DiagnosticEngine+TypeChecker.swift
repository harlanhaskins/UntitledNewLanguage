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

    func cannotTakeAddress(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "cannot take address of value of type '\(type)'", category: "type-checker")
    }

    func cannotAssign(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "cannot assign to type '\(type)'", category: "type-checker")
    }

    func cannotDereference(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "cannot dereference value of non-pointer type '\(type)'", category: "type-checker")
    }

    func invalidBinaryOperands(at range: SourceRange, op: String, lhs: any TypeProtocol, rhs: any TypeProtocol) {
        error(at: range, message: "cannot apply operator '\(op)' to operands of type '\(lhs)' and '\(rhs)'", category: "type-checker")
    }

    func invalidUnaryOperand(at range: SourceRange, op: String, type: any TypeProtocol) {
        error(at: range, message: "cannot apply unary operator '\(op)' to value of type '\(type)'", category: "type-checker")
    }

    func nonBooleanCondition(at range: SourceRange, type: any TypeProtocol) {
        error(at: range, message: "non-boolean condition of type '\(type)'", category: "type-checker")
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

    func missingArgumentLabel(at range: SourceRange, expected: String) {
        error(at: range, message: "missing argument label '\(expected):'", category: "type-checker")
    }

    func unexpectedArgumentLabel(at range: SourceRange, got: String) {
        error(at: range, message: "unexpected argument label '\(got):'", category: "type-checker")
    }

    func incorrectArgumentLabel(at range: SourceRange, expected: String, got: String) {
        error(at: range, message: "incorrect argument label '\(got):' (expected '\(expected):')", category: "type-checker")
    }

    func argumentLabelOrderMismatch(at range: SourceRange, expected: [String], got: [String]) {
        let exp = expected.joined(separator: ", ")
        let g = got.joined(separator: ", ")
        error(at: range, message: "argument labels out of order; expected [\(exp)] but got [\(g)]", category: "type-checker")
    }
}
