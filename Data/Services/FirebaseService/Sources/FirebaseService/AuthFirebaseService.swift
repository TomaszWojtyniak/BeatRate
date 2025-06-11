//
//  AuthFirebaseService.swift
//  FirebaseService
//
//  Created by Tomasz Wojtyniak on 11/06/2025.
//

import SwiftUI
import OSLog
import Analytics
import FirebaseAuth
import AuthenticationServices

public protocol AuthFirebaseServiceProtocol: Sendable {
    func setLoginData(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws
}

public actor AuthFirebaseService: AuthFirebaseServiceProtocol{
    public static let shared = AuthFirebaseService()
    static var logger: Logger {
        return Logger.for(Self.self)
    }
    
    private init() {
        
    }
    
    public func setLoginData(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws {
        Self.logger.debug("Initialize a Firebase credential")
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                          rawNonce: nonce,
                                                          fullName: appleIDCredential.fullName)
        
        Self.logger.debug("Sign in with Firebase")
        _ = try await Auth.auth().signIn(with: credential)
        Self.logger.debug("Firebase auth login successful")
    }
}
