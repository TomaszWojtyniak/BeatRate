//
//  AppleSignInCredential.swift
//  FirebaseService
//

import Foundation
import AuthenticationServices

/// The parts of a Sign in with Apple credential the app uses. Everything below
/// Presentation takes this instead of `ASAuthorization`, which has no public
/// initializer and so cannot be built in tests.
nonisolated public struct AppleSignInCredential: Sendable {
    /// Apple's stable user identifier, saved to the Keychain.
    public let user: String
    public let identityToken: Data?
    /// Needed to revoke the Apple token when the account is deleted.
    public let authorizationCode: Data?
    /// Only sent on the very first sign-in.
    public let email: String?
    /// Only sent on the very first sign-in.
    public let fullName: PersonNameComponents?

    public init(user: String, identityToken: Data?, authorizationCode: Data?, email: String?, fullName: PersonNameComponents?) {
        self.user = user
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.email = email
        self.fullName = fullName
    }

    /// Nil when the authorization is not a Sign in with Apple credential.
    @MainActor
    public init?(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return nil }
        self.init(
            user: credential.user,
            identityToken: credential.identityToken,
            authorizationCode: credential.authorizationCode,
            email: credential.email,
            fullName: credential.fullName
        )
    }
}
