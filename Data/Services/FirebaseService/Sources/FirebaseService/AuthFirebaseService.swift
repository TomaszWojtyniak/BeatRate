//
//  AuthFirebaseService.swift
//  FirebaseService
//
//  Created by Tomasz Wojtyniak on 11/06/2025.
//

import SwiftUI
import OSLog
import Analytics
@preconcurrency import FirebaseAuth
import AuthenticationServices

public protocol AuthFirebaseServiceProtocol: Sendable {
    func setLoginData(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws -> String
}

public actor AuthFirebaseService: AuthFirebaseServiceProtocol {
    public static let shared = AuthFirebaseService()
    let analyticsManager: AnalyticsManager
    let crashLogger: CrashLogger
    
    private init(analyticsManager: AnalyticsManager = .shared,
                 crashLogger: CrashLogger = .shared) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
    }
    
    public func setLoginData(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws -> String {
        Logger.firebaseService.debug("Initialize a Firebase credential")
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                          rawNonce: nonce,
                                                          fullName: appleIDCredential.fullName)
        
        Logger.firebaseService.debug("Sign in with Firebase")
        let userId = try await Auth.auth().signIn(with: credential).user.uid
        Logger.firebaseService.debug("Firebase auth login successful")
        return userId
    }
}
