//
//  FakeRealtimeDatabase.swift
//  FirebaseServiceFakes
//

import FirebaseService
import Foundation

/// What a failing path in `FakeRealtimeDatabase` throws.
nonisolated public struct FakeDatabaseError: Error, Equatable {
    public let path: String

    public init(path: String) {
        self.path = path
    }
}

/// In-memory Realtime Database tree with Firebase's write semantics: `nil`,
/// `NSNull` and empty dictionaries delete a node, and emptied parents vanish.
/// Paths in `failingReads` / `failingWrites` throw `FakeDatabaseError`; `delay` holds
/// every call back so a test or the CLI can act while one is in flight.
/// Shared by the service tests and the headless CLI.
public actor FakeRealtimeDatabase: RealtimeDatabase {
    private var root: Any?
    private let failingReads: Set<String>
    private let failingWrites: Set<String>
    private let delay: Duration
    public private(set) var updates: [(path: String, keys: Set<String>)] = []

    public init(_ tree: DatabaseValue = DatabaseValue(nil), failingReads: Set<String> = [], failingWrites: Set<String> = [],
                delay: Duration = .zero) {
        root = tree.raw
        self.failingReads = failingReads
        self.failingWrites = failingWrites
        self.delay = delay
    }

    public func value(_ path: String) -> DatabaseValue {
        DatabaseValue(Self.keys(path).reduce(root) { ($0 as? [String: Any])?[$1] })
    }

    public func read(_ path: String) async throws -> DatabaseValue {
        try await wait()
        if failingReads.contains(Self.normalized(path)) { throw FakeDatabaseError(path: Self.normalized(path)) }
        return value(path)
    }

    public func write(_ value: DatabaseValue, to path: String) async throws {
        try await wait()
        if failingWrites.contains(Self.normalized(path)) { throw FakeDatabaseError(path: Self.normalized(path)) }
        root = Self.setting(value.raw, at: Self.keys(path)[...], in: root)
    }

    public func update(_ path: String, with values: [String: DatabaseValue]) async throws {
        updates.append((Self.normalized(path), Set(values.keys.map(Self.normalized))))
        for (key, value) in values {
            try await write(value, to: "\(path)/\(key)")
        }
    }

    nonisolated public func serverTimestamp() -> DatabaseValue {
        DatabaseValue([".sv": "timestamp"])
    }

    private func wait() async throws {
        if delay > .zero { try await Task.sleep(for: delay) }
    }

    private static func keys(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    private static func normalized(_ path: String) -> String {
        keys(path).joined(separator: "/")
    }

    private static func setting(_ value: Any?, at keys: ArraySlice<String>, in node: Any?) -> Any? {
        guard let key = keys.first else { return isEmpty(value) ? nil : value }
        var dictionary = node as? [String: Any] ?? [:]
        dictionary[key] = setting(value, at: keys.dropFirst(), in: dictionary[key])
        return dictionary.isEmpty ? nil : dictionary
    }

    private static func isEmpty(_ value: Any?) -> Bool {
        value == nil || value is NSNull || (value as? [String: Any])?.isEmpty == true
    }
}
