//
//  RealtimeDatabase.swift
//  FirebaseService
//

import Foundation
// TODO: Remove @preconcurrency when Firebase SDK adds Sendable support
@preconcurrency import FirebaseDatabase

/// A JSON-shaped Realtime Database value: dictionaries, arrays, numbers,
/// strings, `NSNull`, or `nil` for a node that does not exist.
// Safety: only ever holds plain JSON-like Foundation values, which are never mutated after wrapping.
nonisolated struct DatabaseValue: @unchecked Sendable {
    let raw: Any?

    init(_ raw: Any?) {
        self.raw = raw
    }
}

/// The handful of path-based RTDB calls the service makes, so the parsing,
/// sorting and aggregate logic can run against an in-memory tree in tests.
nonisolated protocol RealtimeDatabase: Sendable {
    /// The node at `path`, or a `nil` raw value when it does not exist.
    func read(_ path: String) async throws -> DatabaseValue
    /// Replaces the node at `path`; a `nil` raw value removes it.
    func write(_ value: DatabaseValue, to path: String) async throws
    /// Multi-location update relative to `path` (`""` for the root); `NSNull` deletes.
    func update(_ path: String, with values: [String: DatabaseValue]) async throws
    /// Placeholder Firebase fills in with its own clock on write.
    func serverTimestamp() -> DatabaseValue
}

nonisolated struct FirebaseRealtimeDatabase: RealtimeDatabase {
    let url: String

    private func reference(_ path: String) -> DatabaseReference {
        let root = Database.database(url: url).reference()
        return path.isEmpty ? root : root.child(path)
    }

    func read(_ path: String) async throws -> DatabaseValue {
        let snapshot = try await reference(path).getData()
        return DatabaseValue(snapshot.exists() ? snapshot.value : nil)
    }

    func write(_ value: DatabaseValue, to path: String) async throws {
        if let raw = value.raw {
            try await reference(path).setValue(raw)
        } else {
            try await reference(path).removeValue()
        }
    }

    func update(_ path: String, with values: [String: DatabaseValue]) async throws {
        try await reference(path).updateChildValues(values.mapValues { $0.raw ?? NSNull() })
    }

    func serverTimestamp() -> DatabaseValue {
        DatabaseValue(ServerValue.timestamp())
    }
}
