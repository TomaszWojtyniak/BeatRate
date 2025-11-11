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
    func checkUserCredentialState(userId: String) async -> ASAuthorizationAppleIDProvider.CredentialState
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

    public func checkUserCredentialState(userId: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        let appleIDProvider = ASAuthorizationAppleIDProvider()

        do {
            let credentialState = try await appleIDProvider.credentialState(forUserID: userId)
            Logger.loginRepository.info("Credential state for user \(userId): \(String(describing: credentialState))")
            return credentialState
        } catch {
            Logger.loginRepository.error("Error checking credential state: \(error.localizedDescription)")
            return .notFound
        }
    }
}
