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
    func setLoginData(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws -> String
}

public actor AuthFirebaseService: AuthFirebaseServiceProtocol{
    public static let shared = AuthFirebaseService()
    let analyticsManager: AnalyticsManager
    let crashLogger: CrashLogger
    static var logger: Logger {
        return Logger.for(Self.self)
    }
    
    private init(analyticsManager: AnalyticsManager = .shared,
                 crashLogger: CrashLogger = .shared) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
    }
    
    public func setLoginData(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws -> String {
        Self.logger.debug("Initialize a Firebase credential")
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                          rawNonce: nonce,
                                                          fullName: appleIDCredential.fullName)
        
        Self.logger.debug("Sign in with Firebase")
        let authResults = try await Auth.auth().signIn(with: credential)
        Self.logger.debug("Firebase auth login successful")
        return authResults.user.uid
    }
}
