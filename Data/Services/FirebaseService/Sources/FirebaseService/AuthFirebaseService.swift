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
    func postLoginData(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws
}

public actor AuthFirebaseService: AuthFirebaseServiceProtocol{
    public static let shared = AuthFirebaseService()
    static var logger: Logger {
        return Logger.for(Self.self)
    }
    
    private init() {
        
    }
    
    public func postLoginData(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws {
        Self.logger.debug("Initialize a Firebase credential")
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                          rawNonce: nonce,
                                                          fullName: appleIDCredential.fullName)
        
        // Sign in with Firebase.
        Auth.auth().signIn(with: credential) { (authResult, error) in
            Self.logger.info("authResult: \(authResult), error: \(error)")
        }
    }
}
