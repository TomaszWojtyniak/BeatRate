import Foundation

/// The fixture files of one headless session, merged into one JSON tree.
///
/// Sections: `db` (an RTDB export fragment), `dbFailures`, `dbDelayMs`, `music`,
/// `device` and `timing` — see `Edges.fixtures(_:)` for what each one drives.
public struct Fixtures {
    public let tree: [String: Any]

    /// Reads the files in order. Later files win leaf by leaf, so a small file can
    /// override one value of a bigger one without copying the rest.
    public static func load(_ paths: [String]) throws -> Fixtures {
        var tree: [String: Any] = [:]
        for path in paths {
            let file = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(filePath: path)))
            guard let object = file as? [String: Any] else {
                throw FixtureError(description: "\(path): a fixture file is a JSON object")
            }
            tree = merge(tree, object)
        }
        return Fixtures(tree: tree)
    }

    /// The value at a slash-separated path (`db/albums/1/title`), or nil.
    public func value(at path: String) -> Any? {
        path.split(separator: "/").reduce(tree as Any?) { ($0 as? [String: Any])?[String($1)] }
    }

    private static func merge(_ base: [String: Any], _ override: [String: Any]) -> [String: Any] {
        base.merging(override) { old, new in
            guard let old = old as? [String: Any], let new = new as? [String: Any] else { return new }
            return merge(old, new)
        }
    }
}

struct FixtureError: Error, CustomStringConvertible {
    let description: String
}
