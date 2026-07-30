import Foundation

enum JSONValue: Sendable {
    case null, bool(Bool), number(Double), string(String)
    case array([JSONValue]), object([String: JSONValue])

    init(any value: Any) {
        switch value {
        case is NSNull: self = .null
        case let n as NSNumber:
            self = String(cString: n.objCType) == "c" ? .bool(n.boolValue) : .number(n.doubleValue)
        case let s as String: self = .string(s)
        case let a as [Any]: self = .array(a.map(JSONValue.init(any:)))
        case let o as [String: Any]: self = .object(o.mapValues(JSONValue.init(any:)))
        default: self = .null
        }
    }
    var string: String? { if case .string(let x) = self { x } else { nil } }
    var bool: Bool? { if case .bool(let x) = self { x } else { nil } }
    var int: Int? { if case .number(let x) = self { Int(x) } else { nil } }
    var object: [String: JSONValue]? { if case .object(let x) = self { x } else { nil } }
}

struct GeneratedGraph: Sendable {
    let root: Int
    let nodes: [GeneratedNode]
    let callbacks: [GeneratedCallback]
}
struct GeneratedNode: Sendable { let kind: String; let values: JSONValue }
struct GeneratedCallback: Sendable { let name: String?; let source: String; let sha256: String }
struct GeneratedLanguage: Sendable {
    let id: String; let aliases: [String]; let disableAutodetect: Bool; let graph: GeneratedGraph
}
private struct LanguageIndex: Sendable {
    let id: String; let aliases: [String]; let disableAutodetect: Bool
}

public struct GeneratedLanguageMetadata: Hashable, Sendable {
    public let id: String
    public let aliases: [String]
    public let supportsAutodetection: Bool
}

public enum GeneratedGrammarError: Error, CustomStringConvertible {
    case missingResource, malformed(String), unsupportedSchema(Int)
    case invalidRegex(language: String, pattern: String, message: String)
    public var description: String {
        switch self {
        case .missingResource: "Generated grammar resources are missing"
        case .malformed(let x): "Malformed grammar graph: \(x)"
        case .unsupportedSchema(let x): "Unsupported grammar schema \(x)"
        case .invalidRegex(let l, let p, let m): "\(l): invalid regex \(p): \(m)"
        }
    }
}

public final class GeneratedGrammarCatalog: @unchecked Sendable {
    private let directoryURL: URL
    private let schemaVersion: Int
    private let indexes: [LanguageIndex]
    private let byName: [String: LanguageIndex]
    private let lock = NSLock()
    private var loaded: [String: GeneratedLanguage] = [:]

    public var languages: [GeneratedLanguageMetadata] {
        indexes.map { .init(id: $0.id, aliases: $0.aliases, supportsAutodetection: !$0.disableAutodetect) }
    }

    public convenience init() throws {
        let nested = Bundle.module.url(
            forResource: "catalog", withExtension: "json", subdirectory: "Grammars"
        )
        let flattened = Bundle.module.url(
            forResource: "catalog", withExtension: "json"
        )
        guard let url = (nested ?? flattened)?.deletingLastPathComponent()
        else { throw GeneratedGrammarError.missingResource }
        try self.init(directoryURL: url)
    }

    public init(directoryURL: URL) throws {
        self.directoryURL = directoryURL
        let root = try Self.dict(
            JSONSerialization.jsonObject(with: Data(contentsOf: directoryURL.appendingPathComponent("catalog.json"))),
            "catalog"
        )
        schemaVersion = try Self.integer(root["schemaVersion"], "schemaVersion")
        indexes = try Self.array(root["languages"], "languages").map {
            let o = try Self.dict($0, "language")
            return LanguageIndex(
                id: try Self.string(o["id"], "id"),
                aliases: try Self.array(o["aliases"], "aliases").map { try Self.string($0, "alias") },
                disableAutodetect: o["disableAutodetect"] as? Bool ?? false
            )
        }
        var names: [String: LanguageIndex] = [:]
        for item in indexes {
            names[item.id.lowercased()] = item
            for alias in item.aliases { names[alias.lowercased()] = item }
        }
        byName = names
    }

    public func metadata(for name: String) -> GeneratedLanguageMetadata? {
        guard let x = byName[name.lowercased()] else { return nil }
        return .init(id: x.id, aliases: x.aliases, supportsAutodetection: !x.disableAutodetect)
    }

    func definition(for name: String) throws -> GeneratedLanguage? {
        guard let index = byName[name.lowercased()] else { return nil }
        lock.lock()
        if let x = loaded[index.id] { lock.unlock(); return x }
        lock.unlock()
        let root = try Self.dict(
            JSONSerialization.jsonObject(
                with: Data(contentsOf: directoryURL.appendingPathComponent("\(index.id).json"))
            ), "grammar"
        )
        let version = try Self.integer(root["schemaVersion"], "schemaVersion")
        guard version == schemaVersion else { throw GeneratedGrammarError.unsupportedSchema(version) }
        let o = try Self.dict(root["language"], "language")
        let g = try Self.dict(o["graph"], "graph")
        let nodes = try Self.array(g["nodes"], "nodes").map {
            let n = try Self.dict($0, "node")
            return GeneratedNode(
                kind: try Self.string(n["kind"], "node.kind"),
                values: JSONValue(any: n["values"] ?? NSNull())
            )
        }
        let callbacks = try Self.array(g["callbacks"], "callbacks").map {
            let c = try Self.dict($0, "callback")
            return GeneratedCallback(
                name: c["name"] as? String,
                source: try Self.string(c["source"], "callback.source"),
                sha256: try Self.string(c["sha256"], "callback.sha256")
            )
        }
        let value = GeneratedLanguage(
            id: try Self.string(o["id"], "id"),
            aliases: index.aliases,
            disableAutodetect: index.disableAutodetect,
            graph: .init(root: try Self.integer(g["root"], "root"), nodes: nodes, callbacks: callbacks)
        )
        lock.lock(); loaded[index.id] = value; lock.unlock()
        return value
    }

    func releaseDefinition(_ id: String) {
        lock.lock(); loaded.removeValue(forKey: id.lowercased()); lock.unlock()
    }

    private static func dict(_ x: Any?, _ p: String) throws -> [String: Any] {
        guard let x = x as? [String: Any] else { throw GeneratedGrammarError.malformed("\(p) must be object") }
        return x
    }
    private static func array(_ x: Any?, _ p: String) throws -> [Any] {
        guard let x = x as? [Any] else { throw GeneratedGrammarError.malformed("\(p) must be array") }
        return x
    }
    private static func string(_ x: Any?, _ p: String) throws -> String {
        guard let x = x as? String else { throw GeneratedGrammarError.malformed("\(p) must be string") }
        return x
    }
    private static func integer(_ x: Any?, _ p: String) throws -> Int {
        guard let x = x as? NSNumber else { throw GeneratedGrammarError.malformed("\(p) must be number") }
        return x.intValue
    }
}
