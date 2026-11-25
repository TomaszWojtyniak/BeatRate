import Analytics
import CoreApp
import FirebaseService
import Foundation
import Security
import SpotifyService
import Synchronization

nonisolated public enum FakeAuthError: Error, Equatable {
    /// Sign-in flows are not scripted by fixtures yet (phase 5, LoginPrompt).
    case notScripted
}

/// Firebase Auth with the session from `device.firebaseUid`.
public actor FakeFirebaseAuth: FirebaseAuthProviding {
    private var userId: String?

    init(userId: String?) {
        self.userId = userId
    }

    public func currentUserId() async -> String? { userId }
    public func signOut() async throws { userId = nil }

    public func signIn(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> FirebaseSignIn {
        throw FakeAuthError.notScripted
    }
    public func reauthenticate(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        throw FakeAuthError.notScripted
    }
    public func revokeToken(authorizationCode: String) async throws { throw FakeAuthError.notScripted }
    public func deleteCurrentUser() async throws { throw FakeAuthError.notScripted }
}

/// A Keychain that keeps generic passwords by account name, in memory.
nonisolated public final class FakeKeychainBackend: KeychainBackend {
    private let items = Mutex<[String: Data]>([:])

    public init() {}

    public func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        items.withLock { items in
            guard items[Self.account(query)] != nil else { return errSecItemNotFound }
            items[Self.account(query)] = attributes[kSecValueData as String] as? Data
            return errSecSuccess
        }
    }

    public func add(_ attributes: [String: Any]) -> OSStatus {
        items.withLock { $0[Self.account(attributes)] = attributes[kSecValueData as String] as? Data }
        return errSecSuccess
    }

    public func copyMatching(_ query: [String: Any]) -> (OSStatus, AnyObject?) {
        guard let data = items.withLock({ $0[Self.account(query)] }) else { return (errSecItemNotFound, nil) }
        return (errSecSuccess, data as AnyObject)
    }

    public func delete(_ query: [String: Any]) -> OSStatus {
        items.withLock { $0[Self.account(query)] == nil ? errSecItemNotFound : ($0[Self.account(query)] = nil, errSecSuccess).1 }
    }

    private static func account(_ query: [String: Any]) -> String {
        query[kSecAttrAccount as String] as? String ?? ""
    }
}

/// Spotify's Web API has no fixtures yet: every request is a network violation.
nonisolated public struct FakeSpotifyTransport: SpotifyTransport {
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        NetworkGuard.record("missing http fixture: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "?")")
        throw URLError(.resourceUnavailable)
    }
}

/// Keeps the events the app logs, for the `Analytics` node of phase 4.
public final class FakeAnalyticsBackend: AnalyticsBackend {
    public private(set) var events: [String] = []

    public func logEvent(_ name: String, parameters: [String: Any]?) { events.append(name) }
    public func setConsent(analyticsGranted: Bool) {}
    public func setCollectionEnabled(_ enabled: Bool) {}
    public func resetData() {}
    public func setUserProperty(_ value: String?, forName name: String) {}
    public func setUserID(_ userId: String?) {}
}
