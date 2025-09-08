public enum TokenKind: Equatable, Sendable {
    // Keywords
    case `func`
    case `var`
    case `return`
    case `extern`
    
    // Literals
    case identifier(String)
    case integerLiteral(String)
    case stringLiteral(String)
    
    // Operators
    case plus        // +
    case minus       // -
    case star        // * (multiply/pointer)
    case divide      // /
    case modulo      // %
    case assign      // =
    case arrow       // ->
    
    // Delimiters
    case leftParen   // (
    case rightParen  // )
    case leftBrace   // {
    case rightBrace  // }
    case colon       // :
    case comma       // ,
    case underscore  // _
    case at          // @
    case ellipsis    // ...
    
    // Special
    case newline
    case eof
}
