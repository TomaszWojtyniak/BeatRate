//
//  FirebaseRealtimeDatabase.swift
//  FirebaseServiceLive
//

#if os(iOS)
import Foundation
import FirebaseService
// TODO: Remove @preconcurrency when Firebase SDK adds Sendable support
@preconcurrency import FirebaseDatabase

/// `RealtimeDatabase` on the Firebase Realtime Database SDK.
nonisolated public struct FirebaseRealtimeDatabase: RealtimeDatabase {
    let url: String

    public init(url: String) {
        self.url = url
    }

    private func reference(_ path: String) -> DatabaseReference {
        let root = Database.database(url: url).reference()
        return path.isEmpty ? root : root.child(path)
    }

    public func read(_ path: String) async throws -> DatabaseValue {
        let snapshot = try await reference(path).getData()
        return DatabaseValue(snapshot.exists() ? snapshot.value : nil)
    }

    public func write(_ value: DatabaseValue, to path: String) async throws {
        if let raw = value.raw {
            try await reference(path).setValue(raw)
        } else {
            try await reference(path).removeValue()
        }
    }

    public func update(_ path: String, with values: [String: DatabaseValue]) async throws {
        try await reference(path).updateChildValues(values.mapValues { $0.raw ?? NSNull() })
    }

    public func serverTimestamp() -> DatabaseValue {
        DatabaseValue(ServerValue.timestamp())
    }
}
#endif
