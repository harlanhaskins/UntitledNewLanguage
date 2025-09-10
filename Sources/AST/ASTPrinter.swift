import Base
import Types

public enum ASTPrinter {
    public static func print(declarations: [any Declaration], includeTypes: Bool) -> String {
        var out: [String] = []
        for decl in declarations {
            out.append(printDecl(decl, includeTypes: includeTypes, indent: 0))
        }
        return out.joined(separator: "\n")
    }

    private static func symbol(_ op: BinaryOperator) -> String {
        switch op {
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "*"
        case .divide: return "/"
        case .modulo: return "%"
        case .logicalAnd: return "&&"
        case .logicalOr: return "||"
        case .equal: return "=="
        case .notEqual: return "!="
        case .lessThan: return "<"
        case .lessThanOrEqual: return "<="
        case .greaterThan: return ">"
        case .greaterThanOrEqual: return ">="
        }
    }

    private static func symbol(_ op: UnaryOperator) -> String {
        switch op {
        case .negate: return "-"
        case .logicalNot: return "!"
        case .addressOf: return "&"
        case .dereference: return "*"
        }
    }

    private static func printDecl(_ decl: any Declaration, includeTypes: Bool, indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        switch decl {
        case let s as StructDeclaration:
            var lines: [String] = []
            lines.append("\(pad)(struct \(s.name)")
            for f in s.fields {
                let t = f.type?.resolvedType?.description ?? (f.type.map { t in (t as? NominalTypeNode)?.name ?? "?" } ?? "?")
                if includeTypes {
                    lines.append("\(pad)  (field \(f.name): \(t))")
                } else {
                    lines.append("\(pad)  (field \(f.name))")
                }
            }
            for m in s.methods {
                lines.append(printDecl(m, includeTypes: includeTypes, indent: indent + 2))
            }
            lines.append("\(pad))")
            return lines.joined(separator: "\n")
        case let f as FunctionDeclaration:
            var sig = "(func \(f.name) (params"
            for p in f.parameters {
                let t = p.type.resolvedType?.description ?? (p.type as? NominalTypeNode)?.name ?? "?"
                if includeTypes {
                    sig += " (\(p.name): \(t))"
                } else {
                    sig += " (\(p.name))"
                }
            }
            sig += ")"
            if includeTypes {
                let rt = f.resolvedReturnType?.description ?? f.returnType?.resolvedType?.description ?? "Void"
                sig += " (return \(rt))"
            }
            var lines: [String] = []
            lines.append(String(repeating: " ", count: indent) + sig)
            if let body = f.body {
                lines.append(printStmt(body, includeTypes: includeTypes, indent: indent + 2))
            }
            lines.append(String(repeating: " ", count: indent) + ")")
            return lines.joined(separator: "\n")
        default:
            return pad + "(unknown-decl)"
        }
    }

    private static func printStmt(_ stmt: any Statement, includeTypes: Bool, indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        switch stmt {
        case let b as Block:
            var lines: [String] = []
            lines.append("\(pad)(block")
            for s in b.statements {
                lines.append(printStmt(s, includeTypes: includeTypes, indent: indent + 2))
            }
            lines.append("\(pad))")
            return lines.joined(separator: "\n")
        case let v as VarBinding:
            var s = "\(pad)(var \(v.name)"
            if includeTypes, let t = v.type?.resolvedType?.description ?? v.value?.resolvedType?.description {
                s += ": \(t)"
            }
            if let val = v.value {
                s += " = \(printExpr(val, includeTypes: includeTypes))"
            }
            s += ")"
            return s
        case let a as AssignStatement:
            return "\(pad)(assign \(a.name) = \(printExpr(a.value, includeTypes: includeTypes)))"
        case let ma as MemberAssignStatement:
            let path = ([ma.baseName] + ma.memberPath).joined(separator: ".")
            return "\(pad)(assign \(path) = \(printExpr(ma.value, includeTypes: includeTypes)))"
        case let la as LValueAssignStatement:
            return "\(pad)(assign \(printExpr(la.target, includeTypes: includeTypes)) = \(printExpr(la.value, includeTypes: includeTypes)))"
        case let r as ReturnStatement:
            if let v = r.value {
                return "\(pad)(return \(printExpr(v, includeTypes: includeTypes)))"
            } else { return "\(pad)(return)" }
        case let e as ExpressionStatement:
            return "\(pad)(expr \(printExpr(e.expression, includeTypes: includeTypes)))"
        case let iff as IfStatement:
            var lines: [String] = []
            lines.append("\(pad)(if")
            for c in iff.clauses {
                lines.append("\(pad)  (cond \(printExpr(c.condition, includeTypes: includeTypes)))")
                lines.append(printStmt(c.block, includeTypes: includeTypes, indent: indent + 4))
            }
            if let e = iff.elseBlock {
                lines.append("\(pad)  (else)")
                lines.append(printStmt(e, includeTypes: includeTypes, indent: indent + 4))
            }
            lines.append("\(pad))")
            return lines.joined(separator: "\n")
        default:
            return pad + "(unknown-stmt)"
        }
    }

    private static func printExpr(_ expr: any Expression, includeTypes: Bool) -> String {
        let typeSuffix: String = {
            if includeTypes, let t = expr.resolvedType { return ": \(t)" } else { return "" }
        }()
        switch expr {
        case let id as IdentifierExpression:
            return "(id \(id.name)\(typeSuffix))"
        case let il as IntegerLiteralExpression:
            return "(int \(il.value)\(typeSuffix))"
        case let sl as StringLiteralExpression:
            return "(str \(sl.value)\(typeSuffix))"
        case let bl as BooleanLiteralExpression:
            return "(bool \(bl.value)\(typeSuffix))"
        case let bin as BinaryExpression:
            return "(bin \(printExpr(bin.left, includeTypes: includeTypes)) \(symbol(bin.`operator`)) \(printExpr(bin.right, includeTypes: includeTypes))\(typeSuffix))"
        case let un as UnaryExpression:
            return "(un \(symbol(un.`operator`)) \(printExpr(un.operand, includeTypes: includeTypes))\(typeSuffix))"
        case let call as CallExpression:
            let args = call.arguments.map { arg in
                let val = printExpr(arg.value, includeTypes: includeTypes)
                if let l = arg.label { return "\(l): \(val)" }
                return val
            }.joined(separator: " ")
            return "(call \(printExpr(call.function, includeTypes: includeTypes)) [\(args)]\(typeSuffix))"
        case let mem as MemberAccessExpression:
            return "(member \(printExpr(mem.base, includeTypes: includeTypes)).\(mem.member)\(typeSuffix))"
        case let cast as CastExpression:
            return "(cast \(printExpr(cast.expression, includeTypes: includeTypes)) as \(cast.targetType.resolvedType?.description ?? "?" )\(typeSuffix))"
        default:
            return "(unknown-expr)"
        }
    }
}
