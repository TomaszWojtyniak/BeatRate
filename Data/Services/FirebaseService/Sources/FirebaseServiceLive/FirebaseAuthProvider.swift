//
//  FirebaseAuthProvider.swift
//  FirebaseServiceLive
//

#if os(iOS)
import Foundation
import FirebaseService
// FIXME: Remove @preconcurrency once Firebase SDK adopts Swift 6 Sendable conformance
// Safety: FirebaseAuth operations are internally thread-safe, though not marked Sendable
@preconcurrency import FirebaseAuth

/// `FirebaseAuthProviding` on the Firebase Auth SDK, with Sign in with Apple as the provider.
nonisolated public struct FirebaseAuthProvider: FirebaseAuthProviding {
    public init() {}

    public func currentUserId() async -> String? {
        Auth.auth().currentUser?.uid
    }

    public func signIn(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> FirebaseSignIn {
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: rawNonce, fullName: fullName)
        let result = try await Auth.auth().signIn(with: credential)
        return FirebaseSignIn(
            userId: result.user.uid,
            email: result.user.email,
            isNewUser: result.additionalUserInfo?.isNewUser ?? false
        )
    }

    public func signOut() async throws {
        try Auth.auth().signOut()
    }

    public func reauthenticate(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthFirebaseServiceError.noCurrentUser
        }
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: rawNonce, fullName: fullName)
        try await user.reauthenticate(with: credential)
    }

    public func revokeToken(authorizationCode: String) async throws {
        try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
    }

    public func deleteCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthFirebaseServiceError.noCurrentUser
        }
        try await user.delete()
    }
}
#endif
