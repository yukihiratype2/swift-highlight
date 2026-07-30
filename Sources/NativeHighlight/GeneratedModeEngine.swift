import Foundation

private struct GeneratedKeyword: Sendable {
    let scope: String
    let relevance: Int
}

private final class GeneratedMode: @unchecked Sendable {
    let id: Int
    var scope: String?
    var begin: NSRegularExpression?
    var end: NSRegularExpression?
    var illegal: NSRegularExpression?
    var matcher: NSRegularExpression?
    var dispatch: [(group: Int, type: String, child: GeneratedMode?)] = []
    #if canImport(CNativeRegex)
    var nativeMatcher: NativeCombinedRegex?
    var nativeDispatchGroups: [UInt32] = []
    #endif
    var contains: [GeneratedMode] = []
    var starts: GeneratedMode?
    var keywords: [String: GeneratedKeyword] = [:]
    var beginScope: [Int: String] = [:]
    var endScope: [Int: String] = [:]
    var relevance = 1
    var excludeBegin = false
    var excludeEnd = false
    var returnEnd = false
    var skip = false
    var beforeBeginCallback: String?
    var onBeginCallback: String?

    init(id: Int) { self.id = id }
}

private final class GeneratedCompiler {
    let language: GeneratedLanguage
    let caseInsensitive: Bool
    private var modes: [Int: GeneratedMode] = [:]

    init(language: GeneratedLanguage) {
        self.language = language
        caseInsensitive = language.graph.nodes[language.graph.root]
            .values.object?["case_insensitive"]?.bool ?? false
    }

    func compile() throws -> GeneratedMode { try mode(language.graph.root) }

    private func mode(_ id: Int) throws -> GeneratedMode {
        if let x = modes[id] { return x }
        guard language.graph.nodes.indices.contains(id),
              let o = language.graph.nodes[id].values.object else {
            throw GeneratedGrammarError.malformed("\(language.id): mode \(id)")
        }
        let x = GeneratedMode(id: id)
        modes[id] = x
        x.scope = o["scope"]?.string ?? o["className"]?.string
        x.relevance = o["relevance"]?.int ?? 1
        x.excludeBegin = o["excludeBegin"]?.bool ?? false
        x.excludeEnd = o["excludeEnd"]?.bool ?? false
        x.returnEnd = o["returnEnd"]?.bool ?? false
        x.skip = o["skip"]?.bool ?? false
        x.beforeBeginCallback = callback(o["__beforeBegin"])
        x.onBeginCallback = callback(o["on:begin"])
        x.begin = try regex(o["begin"], fallback: id == language.graph.root ? nil : "\\B|\\b")
        x.end = try regex(o["end"], fallback: id == language.graph.root ? nil : "\\B|\\b")
        x.illegal = try regex(o["illegal"], fallback: nil)
        x.beginScope = scopeMap(o["beginScope"])
        x.endScope = scopeMap(o["endScope"])
        x.keywords = keywordMap(o["keywords"])
        if let values = referencedArray(o["contains"]) {
            x.contains = try values.compactMap {
                guard let child = reference($0) else { return nil }
                return try mode(child)
            }
        }
        if let values = referencedArray(o["__nativeMatcherDispatch"]) {
            x.dispatch = values.compactMap { entry in
                guard let eid = reference(entry),
                      language.graph.nodes.indices.contains(eid),
                      let e = language.graph.nodes[eid].values.object,
                      let group = e["group"]?.int,
                      let type = e["type"]?.string else { return nil }
                return (
                    group, type,
                    reference(e["rule"]).flatMap { try? mode($0) }
                )
            }
        }
        let matcherPattern = pattern(o["__nativeMatcher"], fallback: nil)
        #if canImport(CNativeRegex)
        if let matcherPattern {
            x.nativeMatcher = NativeCombinedRegex(
                pattern: normalize(matcherPattern), caseInsensitive: caseInsensitive
            )
            x.nativeDispatchGroups = x.dispatch.map { UInt32($0.group) }
            if x.nativeMatcher == nil,
               ProcessInfo.processInfo.environment["NATIVE_HIGHLIGHT_REGEX_DIAGNOSTICS"] != nil {
                FileHandle.standardError.write(
                    Data("PCRE2 fallback: \(language.id) mode \(id)\n".utf8)
                )
            }
        }
        if x.nativeMatcher == nil {
            x.matcher = try regex(matcherPattern)
        }
        #else
        x.matcher = try regex(matcherPattern)
        #endif
        if let sid = reference(o["starts"]) { x.starts = try mode(sid) }
        return x
    }

    private func callback(_ value: JSONValue?) -> String? {
        value?.object?["$callback"]?.string
    }
    private func reference(_ value: JSONValue?) -> Int? {
        value?.object?["$ref"]?.int
    }
    private func referencedArray(_ value: JSONValue?) -> [JSONValue]? {
        guard let id = reference(value), language.graph.nodes.indices.contains(id),
              case .array(let a) = language.graph.nodes[id].values else { return nil }
        return a
    }
    private func scopeMap(_ value: JSONValue?) -> [Int: String] {
        if let s = value?.string { return [0:s] }
        guard let id = reference(value), language.graph.nodes.indices.contains(id),
              let o = language.graph.nodes[id].values.object else { return [:] }
        return Dictionary(uniqueKeysWithValues: o.compactMap {
            guard let i = Int($0.key), let s = $0.value.string else { return nil }
            return (i,s)
        })
    }
    private func keywordMap(_ value: JSONValue?) -> [String: GeneratedKeyword] {
        guard let id = reference(value), language.graph.nodes.indices.contains(id),
              let o = language.graph.nodes[id].values.object else { return [:] }
        var result: [String: GeneratedKeyword] = [:]
        for (word, entry) in o where word != "$pattern" {
            guard let a = referencedArray(entry), a.count >= 2,
                  let scope = a[0].string, let relevance = a[1].int else { continue }
            result[caseInsensitive ? word.lowercased() : word] = .init(
                scope: scope, relevance: relevance
            )
        }
        return result
    }

    private func pattern(_ value: JSONValue?, fallback: String?) -> String? {
        value?.string
            ?? value?.object?["$regex"]?.object?["source"]?.string
            ?? fallback
    }

    private func regex(_ value: JSONValue?, fallback: String?) throws -> NSRegularExpression? {
        try regex(pattern(value, fallback: fallback))
    }

    private func regex(_ pattern: String?) throws -> NSRegularExpression? {
        guard let pattern, !pattern.isEmpty else { return nil }
        let normalized = normalize(pattern)
        var options: NSRegularExpression.Options = [.anchorsMatchLines]
        if caseInsensitive { options.insert(.caseInsensitive) }
        do { return try NSRegularExpression(pattern: normalized, options: options) }
        catch {
            throw GeneratedGrammarError.invalidRegex(
                language: language.id, pattern: pattern, message: String(describing: error)
            )
        }
    }

    private func normalize(_ pattern: String) -> String {
        let input = Array(pattern
            .replacingOccurrences(of: "[^]", with: #"(?:[\s\S])"#)
            .replacingOccurrences(of: "[:]", with: ":")
            .replacingOccurrences(of: #"\'"#, with: "'"))
        var out = "", i = 0, inClass = false, classCount = 0
        while i < input.count {
            let c = input[i]
            if c == "\\", i + 1 < input.count {
                if input[i+1] == "u", i + 5 < input.count,
                   input[(i+2)...(i+5)].allSatisfy({ $0.isHexDigit }) {
                    out += "\\x{" + String(input[(i+2)...(i+5)]) + "}"
                    i += 6
                    if inClass { classCount += 1 }
                    continue
                }
                out.append(c); out.append(input[i+1]); i += 2
                if inClass { classCount += 1 }
                continue
            }
            if c == "[" {
                if inClass { out += #"\["#; classCount += 1 }
                else { out.append(c); inClass = true; classCount = 0 }
            } else if c == "]", inClass {
                if classCount == 0 || (classCount == 1 && out.last == "^") {
                    out += #"\]"#; classCount += 1
                } else { out.append(c); inClass = false }
            } else if c == "{", !inClass {
                let rest = String(input[i...])
                if i >= 2, input[i-2] == "\\", input[i-1] == "p" || input[i-1] == "P",
                   let close = rest.firstIndex(of: "}") {
                    let part = String(rest[...close]); out += part; i += part.count; continue
                } else if let r = rest.range(
                    of: #"^\{\d+(?:,\d*)?\}"#, options: .regularExpression
                ) {
                    let part = String(rest[r]); out += part; i += part.count; continue
                } else { out += #"\{"# }
            } else if c == "}", !inClass { out += #"\}"# }
            else {
                out.append(c)
                if inClass && !(c == "^" && classCount == 0) { classCount += 1 }
            }
            i += 1
        }
        return out
    }
}

public final class GeneratedModeHighlighter: @unchecked Sendable {
    public let catalog: GeneratedGrammarCatalog
    private let lock = NSLock()
    private var compiled: [String:(root:GeneratedMode,caseInsensitive:Bool)] = [:]

    public init(catalog: GeneratedGrammarCatalog) { self.catalog = catalog }
    public convenience init() throws { try self.init(catalog: GeneratedGrammarCatalog()) }

    public func highlight(_ source: String, language: String) throws -> HighlightResult {
        guard let metadata = catalog.metadata(for: language) else {
            throw HighlightError.unknownLanguage(language)
        }
        let state = try compiledLanguage(metadata.id)
        var parser = GeneratedParser(source: source, caseInsensitive: state.caseInsensitive)
        parser.parseRoot(state.root)
        return .init(
            language: metadata.id, relevance: parser.relevance,
            tokens: parser.finalizeTokens(), source: source
        )
    }

    public func highlightHTML(
        _ source: String, language: String, classPrefix: String = "hljs-"
    ) throws -> String {
        guard let metadata = catalog.metadata(for: language) else {
            throw HighlightError.unknownLanguage(language)
        }
        let state = try compiledLanguage(metadata.id)
        var parser = GeneratedParser(source: source, caseInsensitive: state.caseInsensitive)
        parser.parseRoot(state.root)
        return parser.finalizeHTML(classPrefix: classPrefix)
    }

    public func highlightAuto(_ source: String, languages: [String]? = nil) -> HighlightResult {
        let names = languages ?? catalog.languages.filter(\.supportsAutodetection).map(\.id)
        return names.compactMap { try? highlight(source, language: $0) }
            .max { $0.relevance < $1.relevance }
            ?? .init(
                language: nil, relevance: 0,
                tokens: [.init(kind: .plain, text: source, range: source.startIndex..<source.endIndex)],
                source: source
            )
    }

    private func compiledLanguage(
        _ id: String
    ) throws -> (root:GeneratedMode,caseInsensitive:Bool) {
        lock.lock()
        if let x = compiled[id] { lock.unlock(); return x }
        lock.unlock()
        guard let definition = try catalog.definition(for: id) else {
            throw HighlightError.unknownLanguage(id)
        }
        let compiler = GeneratedCompiler(language: definition)
        let value = (try compiler.compile(), compiler.caseInsensitive)
        catalog.releaseDefinition(id)
        lock.lock(); compiled[id] = value; lock.unlock()
        return value
    }
}
public typealias FullHighlighter = GeneratedModeHighlighter

private struct PendingToken {
    let kind: TokenKind
    var range: NSRange
}

private struct ParseEvent {
    let range: NSRange
    let child: GeneratedMode?
    let type: String
}

private struct GeneratedParser {
    private static let keywordRegex = try! NSRegularExpression(
        pattern: #"\b[\p{L}_$][\p{L}\p{N}_$]*\b"#
    )
    let source: String
    let nsSource: NSString
    let utf16: [UInt16]
    let length: Int
    let caseInsensitive: Bool
    private var pending: [PendingToken] = []
    private var keywordHits: [String:Int] = [:]
    var relevance = 0

    init(source: String, caseInsensitive: Bool) {
        self.source = source
        nsSource = source as NSString
        utf16 = Array(source.utf16)
        length = utf16.count
        self.caseInsensitive = caseInsensitive
        pending.reserveCapacity(max(16, source.utf8.count / 12))
    }

    mutating func parseRoot(_ mode: GeneratedMode) {
        _ = parse(mode, from: 0, limit: length, ownsOpening: false)
    }

    mutating func finalizeTokens() -> [HighlightToken] {
        normalizedPending().compactMap { token in
            guard let swiftRange = Range(token.range, in: source) else { return nil }
            return .init(
                kind: token.kind,
                text: String(source[swiftRange]),
                range: swiftRange
            )
        }
    }

    mutating func finalizeHTML(classPrefix: String) -> String {
        let tokens = normalizedPending()
        var output: [UInt8] = []
        output.reserveCapacity(source.utf8.count + tokens.count * 24)
        let sourceBytes = Array(source.utf8)
        let ascii = sourceBytes.count == utf16.count
        for token in tokens {
            if token.kind != .plain {
                output.append(contentsOf: "<span class=\"".utf8)
                output.append(contentsOf: classPrefix.utf8)
                output.append(contentsOf: token.kind.rawValue.utf8)
                output.append(contentsOf: "\">".utf8)
            }
            if ascii {
                appendEscaped(
                    sourceBytes[token.range.location..<NSMaxRange(token.range)], to: &output
                )
            } else if let swiftRange = Range(token.range, in: source) {
                appendEscaped(source[swiftRange].utf8, to: &output)
            }
            if token.kind != .plain { output.append(contentsOf: "</span>".utf8) }
        }
        return String(decoding: output, as: UTF8.self)
    }

    private mutating func normalizedPending() -> [PendingToken] {
        var repaired: [PendingToken] = []
        repaired.reserveCapacity(pending.count + 2)
        var cursor = 0
        for token in pending {
            let end = NSMaxRange(token.range)
            guard end > cursor else { continue }
            if token.range.location > cursor {
                repaired.append(.init(
                    kind: .plain,
                    range: NSRange(location: cursor, length: token.range.location - cursor)
                ))
            }
            let start = max(cursor, token.range.location)
            repaired.append(.init(
                kind: token.kind,
                range: NSRange(location: start, length: end - start)
            ))
            cursor = end
        }
        if cursor < length {
            repaired.append(.init(kind: .plain, range: NSRange(location: cursor, length: length-cursor)))
        }
        return repaired
    }

    private func appendEscaped<S: Sequence>(
        _ bytes: S, to output: inout [UInt8]
    ) where S.Element == UInt8 {
        for byte in bytes {
            switch byte {
            case 38: output.append(contentsOf: "&amp;".utf8)
            case 60: output.append(contentsOf: "&lt;".utf8)
            case 62: output.append(contentsOf: "&gt;".utf8)
            case 34: output.append(contentsOf: "&quot;".utf8)
            case 39: output.append(contentsOf: "&#x27;".utf8)
            default: output.append(byte)
            }
        }
    }

    private mutating func parse(
        _ mode: GeneratedMode, from start: Int, limit: Int, ownsOpening: Bool
    ) -> Int {
        var cursor = start
        let scope = mode.skip ? nil : mode.scope
        if ownsOpening { relevance += mode.relevance }

        while cursor < limit {
            let search = NSRange(location: cursor, length: limit-cursor)
            var event: ParseEvent?
            #if canImport(CNativeRegex)
            if let matcher = mode.nativeMatcher {
                if let match = matcher.firstMatch(
                    subject: utf16, start: cursor, groups: mode.nativeDispatchGroups
                ), match.range.location < limit,
                   mode.dispatch.indices.contains(match.dispatchIndex) {
                    event = resolvedEvent(
                        for: mode.dispatch[match.dispatchIndex],
                        range: match.range, mode: mode, limit: limit
                    )
                }
            } else {
                event = foundationEvent(mode, search: search, limit: limit)
            }
            #else
            event = foundationEvent(mode, search: search, limit: limit)
            #endif

            guard let event else {
                emit(NSRange(location: cursor, length: limit-cursor), scope: scope, keywords: mode.keywords)
                return limit
            }
            if event.range.location > cursor {
                emit(
                    NSRange(location: cursor, length: event.range.location-cursor),
                    scope: scope, keywords: mode.keywords
                )
            }
            if event.type == "illegal" {
                append(scope: scope, range: event.range)
                cursor = event.range.length == 0
                    ? min(limit, nextScalarOffset(cursor))
                    : NSMaxRange(event.range)
                continue
            }
            if event.type == "end" {
                if mode.returnEnd { return event.range.location }
                if mode.excludeEnd { append(scope: nil, range: event.range) }
                else { emitCaptures(event.range, regex: mode.end, scopes: mode.endScope, fallback: scope) }
                return NSMaxRange(event.range)
            }
            guard let child = event.child else { return NSMaxRange(event.range) }
            if child.excludeBegin {
                emit(event.range, scope: scope, keywords: mode.keywords)
            } else {
                emitCaptures(
                    event.range, regex: child.begin, scopes: child.beginScope,
                    fallback: child.skip ? scope : child.scope
                )
            }
            cursor = parse(
                child, from: NSMaxRange(event.range), limit: limit, ownsOpening: true
            )
            if let starts = child.starts {
                cursor = parse(starts, from: cursor, limit: limit, ownsOpening: false)
            }
            if cursor <= event.range.location {
                cursor = max(NSMaxRange(event.range), min(limit,nextScalarOffset(cursor)))
            }
        }
        return cursor
    }

    private func nextScalarOffset(_ offset: Int) -> Int {
        guard offset < utf16.count else { return offset + 1 }
        let unit = utf16[offset]
        if (0xD800...0xDBFF).contains(unit), offset + 1 < utf16.count,
           (0xDC00...0xDFFF).contains(utf16[offset + 1]) {
            return offset + 2
        }
        return offset + 1
    }

    private func foundationEvent(
        _ mode: GeneratedMode, search: NSRange, limit: Int
    ) -> ParseEvent? {
        guard let matcher = mode.matcher else {
            return fallbackEvent(mode, search: search)
        }
        guard let match = matcher.firstMatch(in: source, range: search),
              let item = mode.dispatch.first(where: {
                  $0.group < match.numberOfRanges &&
                  match.range(at: $0.group).location != NSNotFound
              }) else { return nil }
        return resolvedEvent(for: item, range: match.range, mode: mode, limit: limit)
    }

    private func resolvedEvent(
        for item: (group: Int, type: String, child: GeneratedMode?),
        range: NSRange, mode: GeneratedMode, limit: Int
    ) -> ParseEvent? {
        if item.type == "begin", let child = item.child,
           acceptsBegin(child, range: range) {
            return .init(range: range, child: child, type: "begin")
        }
        if item.type == "end" {
            return .init(range: range, child: nil, type: "end")
        }
        if item.type == "illegal" {
            return .init(range: range, child: nil, type: "illegal")
        }
        return fallbackEvent(
            mode, search: NSRange(location: range.location, length: limit-range.location)
        )
    }

    private func fallbackEvent(_ mode: GeneratedMode, search: NSRange) -> ParseEvent? {
        var best: ParseEvent?
        if let end = mode.end, let m = end.firstMatch(in: source, range: search) {
            best = .init(range: m.range, child: nil, type: "end")
        }
        for child in mode.contains {
            guard let begin = child.begin, let m = begin.firstMatch(in: source, range: search),
                  acceptsBegin(child, range: m.range) else { continue }
            if best == nil || m.range.location < best!.range.location {
                best = .init(range: m.range, child: child, type: "begin")
            }
        }
        return best
    }

    private func acceptsBegin(_ mode: GeneratedMode, range: NSRange) -> Bool {
        for callback in [mode.beforeBeginCallback,mode.onBeginCallback].compactMap({$0}) {
            switch callback {
            case "ed799d43501ae5019ff044792954d6c81d08451c581c833d0d7214816a13b76a":
                if range.location > 0,
                   nsSource.character(at: range.location-1) == 46 { return false }
            case "c4466892b3170b9c5d735642f68db71cb9691bdf29d486d7b2488bc21e7b7ed3":
                if range.location != 0 { return false }
            case "8e65488e8605e1d2ead40b06eb6492bd40f89b45bf8dfa981992f90efef03a6c":
                if range.location > 0 {
                    let c = nsSource.character(at: range.location-1)
                    if !((48...57).contains(c) || c == 95) { return false }
                }
            case "05097c4c6284fab2338b89a910038278c293b179c601c9b434edb207c31660a2":
                let end = NSMaxRange(range)
                if end < length {
                    let c = nsSource.character(at: end)
                    if c == 60 || c == 44 { return false }
                }
            default: break
            }
        }
        return true
    }

    private mutating func emit(
        _ range: NSRange, scope: String?, keywords: [String:GeneratedKeyword]
    ) {
        guard range.length > 0 else { return }
        guard !keywords.isEmpty else { append(scope: scope, range: range); return }
        var cursor = range.location
        for match in Self.keywordRegex.matches(in: source, range: range) {
            let original = nsSource.substring(with: match.range)
            let lookup = caseInsensitive ? original.lowercased() : original
            guard let keyword = keywords[lookup] else { continue }
            if match.range.location > cursor {
                append(
                    scope: scope,
                    range: NSRange(location: cursor, length: match.range.location-cursor)
                )
            }
            let count = keywordHits[lookup,default:0] + 1
            keywordHits[lookup] = count
            if count <= 7 { relevance += keyword.relevance }
            append(
                scope: keyword.scope.hasPrefix("_") ? scope : keyword.scope,
                range: match.range
            )
            cursor = NSMaxRange(match.range)
        }
        if cursor < NSMaxRange(range) {
            append(scope: scope, range: NSRange(location: cursor, length:NSMaxRange(range)-cursor))
        }
    }

    private mutating func emitCaptures(
        _ range: NSRange, regex: NSRegularExpression?,
        scopes: [Int:String], fallback: String?
    ) {
        if let whole = scopes[0] { append(scope: whole, range: range); return }
        guard !scopes.isEmpty, let regex,
              let match = regex.firstMatch(in: source, options: [.anchored], range: range) else {
            append(scope: fallback, range: range); return
        }
        var cursor = range.location
        for index in scopes.keys.sorted() where index < match.numberOfRanges {
            let capture = match.range(at: index)
            guard capture.location != NSNotFound, capture.location >= cursor else { continue }
            if capture.location > cursor {
                append(scope: fallback, range: NSRange(location: cursor,length:capture.location-cursor))
            }
            append(scope: scopes[index], range: capture)
            cursor = NSMaxRange(capture)
        }
        if cursor < NSMaxRange(range) {
            append(scope: fallback, range: NSRange(location:cursor,length:NSMaxRange(range)-cursor))
        }
    }

    private mutating func append(scope: String?, range: NSRange) {
        guard range.length > 0 else { return }
        let kind = scope.map {
            TokenKind(rawValue: $0.replacingOccurrences(of: ".", with: "-"))
        } ?? .plain
        if !pending.isEmpty, pending[pending.count-1].kind == kind,
           NSMaxRange(pending[pending.count-1].range) == range.location {
            pending[pending.count-1].range.length += range.length
        } else { pending.append(.init(kind: kind, range: range)) }
    }
}
