import Base
import Foundation

public final class Lexer {
    private let source: String
    private var current: String.Index
    private var line: Int = 1
    private var column: Int = 1
    private var offset: Int = 0
    
    public init(source: String) {
        self.source = source
        self.current = source.startIndex
    }
    
    public func tokenize() -> [Token] {
        var tokens: [Token] = []
        
        while !isAtEnd() {
            skipWhitespace()
            
            if isAtEnd() { break }
            
            let token = nextToken()
            tokens.append(token)
        }
        
        let eofLocation = currentLocation()
        tokens.append(Token(kind: .eof, range: SourceRange(start: eofLocation, end: eofLocation)))
        return tokens
    }
    
    private func nextToken() -> Token {
        let start = currentLocation()
        let char = advance()
        
        switch char {
        case "(":
            return makeToken(.leftParen, start: start)
        case ")":
            return makeToken(.rightParen, start: start)
        case "{":
            return makeToken(.leftBrace, start: start)
        case "}":
            return makeToken(.rightBrace, start: start)
        case ":":
            return makeToken(.colon, start: start)
        case ",":
            return makeToken(.comma, start: start)
        case "_":
            return makeToken(.underscore, start: start)
        case "@":
            return makeToken(.at, start: start)
        case "+":
            return makeToken(.plus, start: start)
        case "-":
            if match(">") {
                return makeToken(.arrow, start: start)
            }
            return makeToken(.minus, start: start)
        case "*":
            return makeToken(.star, start: start)
        case "/":
            return makeToken(.divide, start: start)
        case "%":
            return makeToken(.modulo, start: start)
        case "=":
            return makeToken(.assign, start: start)
        case "&":
            if match("&") {
                return makeToken(.logicalAnd, start: start)
            }
            fatalError("Unexpected character: &")
        case "|":
            if match("|") {
                return makeToken(.logicalOr, start: start)
            }
            fatalError("Unexpected character: |")
        case "\n":
            return makeToken(.newline, start: start)
        case ".":
            if match(".") && match(".") {
                return makeToken(.ellipsis, start: start)
            }
            fatalError("Unexpected character: .")
        case "\"":
            return stringLiteral(start: start)
        default:
            if char.isNumber {
                return numberLiteral(start: start)
            } else if char.isLetter {
                return identifier(start: start)
            } else {
                fatalError("Unexpected character: \(char)")
            }
        }
    }
    
    private func stringLiteral(start: SourceLocation) -> Token {
        let contentStart = current
        
        while !isAtEnd() && peek() != "\"" {
            advance()
        }
        
        if isAtEnd() {
            fatalError("Unterminated string")
        }
        
        let value = String(source[contentStart..<current])
        
        // Consume closing quote
        advance()
        
        return makeToken(.stringLiteral(value), start: start)
    }
    
    private func numberLiteral(start: SourceLocation) -> Token {
        let tokenStart = source.index(before: current)
        
        while peek().isNumber {
            advance()
        }
        
        let text = String(source[tokenStart..<current])
        return makeToken(.integerLiteral(text), start: start)
    }
    
    private func identifier(start: SourceLocation) -> Token {
        let tokenStart = source.index(before: current)
        
        while peek().isLetter || peek().isNumber {
            advance()
        }
        
        let text = String(source[tokenStart..<current])
        
        // Check for keywords
        let kind: TokenKind
        switch text {
        case "func":
            kind = .func
        case "var":
            kind = .var
        case "return":
            kind = .return
        case "extern":
            kind = .extern
        case "true":
            kind = .booleanLiteral(true)
        case "false":
            kind = .booleanLiteral(false)
        default:
            kind = .identifier(text)
        }
        
        return makeToken(kind, start: start)
    }
    
    private func skipWhitespace() {
        while !isAtEnd() {
            let char = peek()
            if char == " " || char == "\t" || char == "\r" {
                advance()
            } else {
                break
            }
        }
    }
    
    @discardableResult
    private func advance() -> Character {
        guard !isAtEnd() else { return "\0" }
        let char = source[current]
        current = source.index(after: current)
        
        if char == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        offset += 1
        
        return char
    }
    
    private func peek() -> Character {
        guard !isAtEnd() else { return "\0" }
        return source[current]
    }
    
    private func match(_ expected: Character) -> Bool {
        if isAtEnd() || source[current] != expected {
            return false
        }
        current = source.index(after: current)
        return true
    }
    
    private func isAtEnd() -> Bool {
        return current >= source.endIndex
    }
    
    private func currentLocation() -> SourceLocation {
        return SourceLocation(line: line, column: column, offset: offset)
    }
    
    private func makeToken(_ kind: TokenKind, start: SourceLocation) -> Token {
        let end = currentLocation()
        let range = SourceRange(start: start, end: end)
        return Token(kind: kind, range: range)
    }
}
