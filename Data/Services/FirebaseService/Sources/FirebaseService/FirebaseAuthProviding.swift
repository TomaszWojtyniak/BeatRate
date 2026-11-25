//
//  FirebaseAuthProviding.swift
//  FirebaseService
//

import Foundation

/// What Firebase tells the app about the user it just signed in.
nonisolated public struct FirebaseSignIn: Sendable {
    public let userId: String
    public let email: String?
    public let isNewUser: Bool

    public init(userId: String, email: String?, isNewUser: Bool) {
        self.userId = userId
        self.email = email
        self.isNewUser = isNewUser
    }
}

/// The Firebase Auth calls the app makes, so the sign-in logic runs without the SDK.
nonisolated public protocol FirebaseAuthProviding: Sendable {
    func currentUserId() async -> String?
    func signIn(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> FirebaseSignIn
    func signOut() async throws
    /// Throws `AuthFirebaseServiceError.noCurrentUser` when nobody is signed in.
    func reauthenticate(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws
    func revokeToken(authorizationCode: String) async throws
    /// Throws `AuthFirebaseServiceError.noCurrentUser` when nobody is signed in.
    func deleteCurrentUser() async throws
}
