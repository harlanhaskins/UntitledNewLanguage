public enum TokenKind: Equatable, Sendable {
    // Keywords
    case `func`
    case `var`
    case `struct`
    case `return`
    case extern
    case `true`
    case `false`
    case `if`
    case `else`

    // Literals
    case identifier(String)
    case integerLiteral(String)
    case stringLiteral(String)
    case booleanLiteral(Bool)

    // Operators
    case plus // +
    case minus // -
    case exclamation // ! (logical not)
    case star // * (multiply/pointer)
    case ampersand // & (address-of)
    case divide // /
    case modulo // %
    case assign // =
    case arrow // ->
    case logicalAnd // &&
    case logicalOr // ||

    // Comparison operators
    case equal // ==
    case notEqual // !=
    case lessThan // <
    case lessThanOrEqual // <=
    case greaterThan // >
    case greaterThanOrEqual // >=

    // Delimiters
    case leftParen // (
    case rightParen // )
    case leftBrace // {
    case rightBrace // }
    case colon // :
    case comma // ,
    case underscore // _
    case at // @
    case ellipsis // ...
    case dot // .

    // Special
    case eof
}
