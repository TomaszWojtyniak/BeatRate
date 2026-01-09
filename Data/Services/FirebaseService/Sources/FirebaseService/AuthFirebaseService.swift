//
//  AuthFirebaseService.swift
//  FirebaseService
//
//  Created by Tomasz Wojtyniak on 11/06/2025.
//

import SwiftUI
import OSLog
import Analytics
import Models
import CoreApp
// FIXME: Remove @preconcurrency once Firebase SDK adopts Swift 6 Sendable conformance
// Safety: FirebaseAuth operations are internally thread-safe, though not marked Sendable
// Tracking: Firebase SDK Swift 6 migration (https://github.com/firebase/firebase-ios-sdk/issues)
@preconcurrency import FirebaseAuth
import AuthenticationServices

public protocol AuthFirebaseServiceProtocol: Sendable {
    func setLoginData(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws -> String
    func signOut() async throws
}

public actor AuthFirebaseService: AuthFirebaseServiceProtocol {
    public static let shared = AuthFirebaseService()
    let analyticsManager: AnalyticsManager
    let crashLogger: CrashLogger
    let databaseService: DatabaseFirebaseServiceProtocol
    let keychainManager: KeychainManager

    private init(analyticsManager: AnalyticsManager = .shared,
                 crashLogger: CrashLogger = .shared,
                 databaseService: DatabaseFirebaseService = .shared,
                 keychainManager: KeychainManager = .shared) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
        self.databaseService = databaseService
        self.keychainManager = keychainManager
    }
    
    public func setLoginData(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws -> String {
        let authResult = try await signInWithFirebase(idTokenString: idTokenString, nonce: nonce, appleIDCredential: appleIDCredential)
        let userId = authResult.user.uid

        // CRITICAL: Save Apple user ID to Keychain for credential validation
        // This is a hard requirement - if it fails, we must not continue
        do {
            try await keychainManager.saveAppleUserID(appleIDCredential.user)
            Logger.firebaseService.debug("Saved Apple user ID to Keychain")
        } catch {
            Logger.firebaseService.error("CRITICAL: Failed to save Apple user ID to Keychain: \(error.localizedDescription)")
            await crashLogger.reportToCrashlytics(error: error)

            // Rollback Firebase authentication since we can't save credentials
            Logger.firebaseService.warning("Rolling back Firebase authentication due to Keychain failure")
            do {
                try Auth.auth().signOut()
                Logger.firebaseService.debug("Successfully rolled back Firebase authentication")
            } catch {
                Logger.firebaseService.error("Failed to rollback Firebase auth: \(error.localizedDescription)")
            }

            // Throw the original Keychain error
            throw error
        }

        await createUserProfileIfNeeded(userId: userId, appleIDCredential: appleIDCredential, firebaseUser: authResult.user)

        return userId
    }

    public func signOut() async throws {
        Logger.firebaseService.debug("Signing out from Firebase")
        try Auth.auth().signOut()
        Logger.firebaseService.debug("Firebase sign out successful")

        // Clean up Keychain
        do {
            try await keychainManager.deleteAppleUserID()
            Logger.firebaseService.debug("Deleted Apple user ID from Keychain")
        } catch {
            Logger.firebaseService.error("Failed to delete Apple user ID from Keychain: \(error.localizedDescription)")
            // Don't throw - Keychain cleanup is not critical for sign out
        }
    }

    private func signInWithFirebase(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws -> AuthDataResult {
        Logger.firebaseService.debug("Initialize a Firebase credential")
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        Logger.firebaseService.debug("Sign in with Firebase")
        let authResult = try await Auth.auth().signIn(with: credential)
        Logger.firebaseService.debug("Firebase auth login successful")

        return authResult
    }

    private func createUserProfileIfNeeded(userId: String, appleIDCredential: ASAuthorizationAppleIDCredential, firebaseUser: FirebaseAuth.User) async {
        do {
            let existingProfile = try await databaseService.getUserProfile(userId: userId)

            if existingProfile == nil {
                let userData = extractUserData(from: appleIDCredential, firebaseUser: firebaseUser)
                await saveNewUserProfile(userId: userId, userData: userData)
            } else {
                Logger.firebaseService.debug("User profile already exists, skipping profile creation")
            }
        } catch {
            Logger.firebaseService.error("Failed to check existing user profile: \(error.localizedDescription)")
            await crashLogger.reportToCrashlytics(error: error)
        }
    }

    private func extractUserData(from appleIDCredential: ASAuthorizationAppleIDCredential, firebaseUser: FirebaseAuth.User) -> (email: String?, firstName: String?, lastName: String?) {
        let email = appleIDCredential.email ?? firebaseUser.email
        let firstName = appleIDCredential.fullName?.givenName
        let lastName = appleIDCredential.fullName?.familyName

        return (email: email, firstName: firstName, lastName: lastName)
    }

    private func saveNewUserProfile(userId: String, userData: (email: String?, firstName: String?, lastName: String?)) async {
        // Only save profile if we have at least one piece of information
        guard userData.email != nil || userData.firstName != nil || userData.lastName != nil else {
            Logger.firebaseService.debug("No user profile data available from Apple Sign In")
            return
        }

        let profile = FirebaseUserProfile(
            email: userData.email,
            firstName: userData.firstName,
            lastName: userData.lastName
        )

        do {
            try await databaseService.saveUserProfile(userId: userId, profile: profile)
            Logger.firebaseService.debug("New user profile created successfully")
        } catch {
            Logger.firebaseService.error("Failed to save user profile: \(error.localizedDescription)")
            await crashLogger.reportToCrashlytics(error: error)
        }
    }
}
