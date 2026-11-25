//
//  RealtimeDatabase.swift
//  FirebaseService
//

import Foundation

/// A JSON-shaped Realtime Database value: dictionaries, arrays, numbers,
/// strings, `NSNull`, or `nil` for a node that does not exist.
// Safety: only ever holds plain JSON-like Foundation values, which are never mutated after wrapping.
nonisolated public struct DatabaseValue: @unchecked Sendable {
    public let raw: Any?

    public init(_ raw: Any?) {
        self.raw = raw
    }
}

/// The handful of path-based RTDB calls the service makes, so the parsing,
/// sorting and aggregate logic can run against an in-memory tree in tests.
nonisolated public protocol RealtimeDatabase: Sendable {
    /// The node at `path`, or a `nil` raw value when it does not exist.
    func read(_ path: String) async throws -> DatabaseValue
    /// Replaces the node at `path`; a `nil` raw value removes it.
    func write(_ value: DatabaseValue, to path: String) async throws
    /// Multi-location update relative to `path` (`""` for the root); `NSNull` deletes.
    func update(_ path: String, with values: [String: DatabaseValue]) async throws
    /// Placeholder Firebase fills in with its own clock on write.
    func serverTimestamp() -> DatabaseValue
}
