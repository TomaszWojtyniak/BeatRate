import Foundation

/// The fixture files of one headless session, merged into one JSON tree.
///
/// Sections: `db` (an RTDB export fragment), `dbFailures`, `dbDelayMs`, `music`,
/// `device` and `timing` — see `Edges.fixtures(_:)` for what each one drives.
/// A typo must not quietly fall back to a default, so unknown keys, unknown values
/// and values of the wrong type are refused with their path.
public struct Fixtures {
    public let tree: [String: Any]

    /// Every key a fixture may set; `/*` takes any subtree.
    static let allowed: Set<String> = [
        "db/*", "dbFailures/reads", "dbFailures/writes", "dbDelayMs",
        "music/authorization", "music/answer", "music/subscription", "music/albums/*",
        "device/firebaseUid", "device/keychain/appleUserID", "device/appleIDState", "device/loggedInUserId", "device/defaults/*",
        "timing/retryDelayMs",
    ]

    /// Reads the files in order. Later files win leaf by leaf, so a small file can
    /// override one value of a bigger one without copying the rest; `null` removes a
    /// key and arrays replace rather than combine.
    public static func load(_ paths: [String]) throws -> Fixtures {
        var tree: [String: Any] = [:]
        for path in paths {
            let file = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(filePath: path)))
            guard let object = file as? [String: Any] else {
                throw FixtureError(description: "\(path): a fixture file is a JSON object")
            }
            try check(object, at: "")
            tree = merge(tree, object)
        }
        return Fixtures(tree: tree)
    }

    /// The value at a slash-separated path (`db/albums/1/title`), or nil.
    public func value(at path: String) -> Any? {
        path.split(separator: "/").reduce(tree as Any?) { ($0 as? [String: Any])?[String($1)] }
    }

    func string(_ path: String) throws -> String? { try typed(path, "a string") { $0 as? String } }
    func strings(_ path: String) throws -> [String]? { try typed(path, "an array of strings") { $0 as? [String] } }
    func object(_ path: String) throws -> [String: Any]? { try typed(path, "an object") { $0 as? [String: Any] } }
    func int(_ path: String) throws -> Int? { try typed(path, "a whole number") { isBool($0) ? nil : $0 as? Int } }
    func bool(_ path: String) throws -> Bool? { try typed(path, "true or false") { isBool($0) ? $0 as? Bool : nil } }

    /// A string value mapped through `choices`; absent means nil, anything else is refused.
    func choice<Value>(_ path: String, _ choices: [String: Value]) throws -> Value? {
        guard let name = try string(path) else { return nil }
        guard let value = choices[name] else {
            throw FixtureError(description: "\(path): unknown value \"\(name)\"; one of \(choices.keys.sorted().joined(separator: ", "))")
        }
        return value
    }

    private func typed<Value>(_ path: String, _ expected: String, _ cast: (Any) -> Value?) throws -> Value? {
        guard let raw = value(at: path) else { return nil }
        guard let value = cast(raw) else { throw FixtureError(description: "\(path): expected \(expected), got \(raw)") }
        return value
    }

    private func isBool(_ value: Any) -> Bool {
        (value as? NSNumber).map { CFGetTypeID($0) == CFBooleanGetTypeID() } ?? false
    }

    private static func check(_ node: [String: Any], at prefix: String) throws {
        for (key, value) in node {
            let path = prefix.isEmpty ? key : "\(prefix)/\(key)"
            if allowed.contains(path) || allowed.contains("\(path)/*") { continue }
            guard allowed.contains(where: { $0.hasPrefix("\(path)/") }) else {
                throw FixtureError(description: "unknown key \(path); fixtures take \(allowed.sorted().joined(separator: ", "))")
            }
            guard let child = value as? [String: Any] else { throw FixtureError(description: "\(path): expected an object") }
            try check(child, at: path)
        }
    }

    /// `null` removes a key — also deep inside an object no earlier file had.
    private static func merge(_ base: [String: Any], _ override: [String: Any]) -> [String: Any] {
        var merged = base
        for (key, new) in override {
            if new is NSNull {
                merged[key] = nil
            } else if let new = new as? [String: Any] {
                merged[key] = merge(merged[key] as? [String: Any] ?? [:], new)
            } else {
                merged[key] = new
            }
        }
        return merged
    }
}

struct FixtureError: Error, CustomStringConvertible {
    let description: String
}
