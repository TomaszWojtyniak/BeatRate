//
//  LoginRepository.swift
//  LoginRepository
//
//  Created by Tomasz Wojtyniak on 27/05/2025.
//

import SwiftUI
import AuthenticationServices
import OSLog
import Analytics
import FirebaseService
import Models

public enum LoginError: Error {
    case wrongData
}

public protocol LoginRepositoryProtocol: Sendable {
    func setLoginData(authResult: ASAuthorization) async throws -> String
    func getCurrentNonce() async -> String
    func getUserProfile(userId: String) async throws -> FirebaseUserProfile?
    func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws
    func signOut() async throws
    func deleteAccount(userId: String, authResult: ASAuthorization) async throws
}

public actor LoginRepository: LoginRepositoryProtocol {
    public static let shared = LoginRepository()

    let authFirebaseService: AuthFirebaseServiceProtocol
    let databaseFirebaseService: DatabaseFirebaseServiceProtocol

    var currentNonce: String?

    private init(authFirebaseService: AuthFirebaseServiceProtocol = AuthFirebaseService.shared,
                 databaseFirebaseService: DatabaseFirebaseServiceProtocol = DatabaseFirebaseService.shared) {
        self.authFirebaseService = authFirebaseService
        self.databaseFirebaseService = databaseFirebaseService
    }
    
    public func getCurrentNonce() async -> String {
        if let nonce = currentNonce {
            return nonce
        }
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
    }
    
    private func randomNonceString(length: Int = 32) -> String {
      precondition(length > 0)
      var randomBytes = [UInt8](repeating: 0, count: length)
      let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
      if errorCode != errSecSuccess {
        fatalError(
          "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
        )
      }

      let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

      let nonce = randomBytes.map { byte in
        // Pick a random character from the set, wrapping around if needed.
        charset[Int(byte) % charset.count]
      }

      return String(nonce)
    }
    
    public func setLoginData(authResult: ASAuthorization) async throws -> String {
        if let appleIDCredential = authResult.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                Logger.loginRepository.error("Unable to fetch identity token")
                throw LoginError.wrongData
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                Logger.loginRepository.error("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                throw LoginError.wrongData
            }
            
            return try await self.authFirebaseService.setLoginData(idTokenString: idTokenString, nonce: nonce, appleIDCredential: appleIDCredential)
        } else {
            throw LoginError.wrongData
        }
    }

    public func getUserProfile(userId: String) async throws -> FirebaseUserProfile? {
        return try await databaseFirebaseService.getUserProfile(userId: userId)
    }

    public func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws {
        try await databaseFirebaseService.saveUserProfile(userId: userId, profile: profile)
        Logger.loginRepository.info("User profile saved successfully for user: \(userId)")
    }

    public func signOut() async throws {
        Logger.loginRepository.info("Signing out user from Firebase")
        try await authFirebaseService.signOut()
        Logger.loginRepository.info("User signed out successfully")
    }

    /// Permanently deletes the account. `authResult` is a fresh Sign in with Apple
    /// re-authentication — required to prove recent login before deletion and to
    /// obtain the authorization code Firebase needs to revoke the Apple token.
    public func deleteAccount(userId: String, authResult: ASAuthorization) async throws {
        guard let appleIDCredential = authResult.credential as? ASAuthorizationAppleIDCredential else {
            throw LoginError.wrongData
        }
        guard let nonce = currentNonce else {
            Logger.loginRepository.error("Account deletion attempted with no nonce in flight")
            throw LoginError.wrongData
        }
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            Logger.loginRepository.error("Unable to serialize identity token for account deletion")
            throw LoginError.wrongData
        }
        let authorizationCode = appleIDCredential.authorizationCode
            .flatMap { String(data: $0, encoding: .utf8) }

        // Order matters: reauth and data wipe must happen while still signed in;
        // the auth user is deleted last.
        try await authFirebaseService.reauthenticate(idTokenString: idTokenString, nonce: nonce, appleIDCredential: appleIDCredential)
        try await databaseFirebaseService.deleteUserData(userId: userId)
        try await authFirebaseService.revokeAndDeleteUser(authorizationCode: authorizationCode)
        Logger.loginRepository.info("Account deleted for user: \(userId)")
    }
}
