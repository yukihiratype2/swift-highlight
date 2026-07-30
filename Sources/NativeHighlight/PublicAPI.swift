import Foundation

public struct TokenKind: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let plain = Self(rawValue: "plain")
    public static let comment = Self(rawValue: "comment")
    public static let keyword = Self(rawValue: "keyword")
    public static let builtIn = Self(rawValue: "built_in")
    public static let type = Self(rawValue: "type")
    public static let literal = Self(rawValue: "literal")
    public static let number = Self(rawValue: "number")
    public static let string = Self(rawValue: "string")
    public static let regexp = Self(rawValue: "regexp")
    public static let symbol = Self(rawValue: "symbol")
    public static let meta = Self(rawValue: "meta")
    public static let title = Self(rawValue: "title")
    public static let function = Self(rawValue: "function")
    public static let attribute = Self(rawValue: "attribute")
    public static let tag = Self(rawValue: "tag")
    public static let variable = Self(rawValue: "variable")
    public static let punctuation = Self(rawValue: "punctuation")
}

public struct HighlightToken: Equatable, Sendable {
    public let kind: TokenKind
    public let text: String
    public let range: Range<String.Index>

    public init(kind: TokenKind, text: String, range: Range<String.Index>) {
        self.kind = kind
        self.text = text
        self.range = range
    }
}

public struct HighlightResult: Sendable {
    public let language: String?
    public let relevance: Int
    public let tokens: [HighlightToken]
    public let source: String

    public var html: String { HTMLRenderer().render(self) }
    public var ansi: String { ANSIRenderer().render(self) }
}

public enum HighlightError: Error, Equatable, CustomStringConvertible {
    case unknownLanguage(String)
    public var description: String {
        switch self { case .unknownLanguage(let name): "Unknown language: \(name)" }
    }
}

public enum Highlighter {
    public static func allLanguages() throws -> FullHighlighter {
        try FullHighlighter()
    }
}

public struct HTMLRenderer: Sendable {
    public let classPrefix: String
    public init(classPrefix: String = "hljs-") { self.classPrefix = classPrefix }
    public func render(_ result: HighlightResult) -> String {
        var output: [UInt8] = []
        output.reserveCapacity(result.source.utf8.count + result.tokens.count * 24)
        let open = Array("<span class=\"".utf8)
        let close = Array("</span>".utf8)
        let quote = Array("\">".utf8)
        let prefix = Array(classPrefix.utf8)
        for token in result.tokens {
            if token.kind != .plain {
                output.append(contentsOf: open)
                output.append(contentsOf: prefix)
                output.append(contentsOf: token.kind.rawValue.utf8)
                output.append(contentsOf: quote)
            }
            for byte in token.text.utf8 {
                switch byte {
                case 38: output.append(contentsOf: "&amp;".utf8)
                case 60: output.append(contentsOf: "&lt;".utf8)
                case 62: output.append(contentsOf: "&gt;".utf8)
                case 34: output.append(contentsOf: "&quot;".utf8)
                case 39: output.append(contentsOf: "&#x27;".utf8)
                default: output.append(byte)
                }
            }
            if token.kind != .plain { output.append(contentsOf: close) }
        }
        return String(decoding: output, as: UTF8.self)
    }
}

public struct ANSIRenderer: Sendable {
    public init() {}
    public func render(_ result: HighlightResult) -> String {
        let colors: [TokenKind: String] = [
            .comment: "\u{001B}[90m", .keyword: "\u{001B}[35m",
            .builtIn: "\u{001B}[36m", .type: "\u{001B}[36m",
            .literal: "\u{001B}[35m", .number: "\u{001B}[34m",
            .string: "\u{001B}[32m", .regexp: "\u{001B}[31m",
            .title: "\u{001B}[33m"
        ]
        return result.tokens.map {
            guard let color = colors[$0.kind] else { return $0.text }
            return color + $0.text + "\u{001B}[0m"
        }.joined()
    }
}
