public struct SourceLocation: Equatable, Sendable, CustomStringConvertible {
    public let line: Int
    public let column: Int
    public let offset: Int

    public init(line: Int, column: Int, offset: Int) {
        self.line = line
        self.column = column
        self.offset = offset
    }

    public var description: String {
        return "\(line):\(column)"
    }
}

public struct SourceRange: Equatable, Sendable, CustomStringConvertible {
    public let start: SourceLocation
    public let end: SourceLocation

    public init(start: SourceLocation, end: SourceLocation) {
        self.start = start
        self.end = end
    }

    public var description: String {
        if start.line == end.line {
            return "\(start.line):\(start.column)-\(end.column)"
        } else {
            return "\(start)-\(end)"
        }
    }
}

public struct Token: Equatable, Sendable {
    public var kind: TokenKind
    public var range: SourceRange
    public var hasTrailingNewline: Bool

    public init(kind: TokenKind, range: SourceRange, hasTrailingNewline: Bool = false) {
        self.kind = kind
        self.range = range
        self.hasTrailingNewline = hasTrailingNewline
    }
}
