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

public protocol LoginRepositoryProtocol: Sendable {
    func setLoginData(authResult: ASAuthorization) async throws
    func getCurrentNonce() async -> String
}

public actor LoginRepository: LoginRepositoryProtocol {
    public static let shared = LoginRepository()
    static var logger: Logger {
        return Logger.for(Self.self)
    }
    
    let authFirebaseService: AuthFirebaseServiceProtocol
    
    var currentNonce: String?
    
    private init(authFirebaseService: AuthFirebaseServiceProtocol = AuthFirebaseService.shared) {
        self.authFirebaseService = authFirebaseService
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
    
    public func setLoginData(authResult: ASAuthorization) async throws {
        if let appleIDCredential = authResult.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                Self.logger.error("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                Self.logger.error("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            
            try await self.authFirebaseService.setLoginData(idTokenString: idTokenString, nonce: nonce, appleIDCredential: appleIDCredential)
        }
    }
}
