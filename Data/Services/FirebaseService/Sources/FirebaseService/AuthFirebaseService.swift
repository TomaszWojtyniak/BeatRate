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

public enum AuthFirebaseServiceError: Error {
    case noCurrentUser
}

public protocol AuthFirebaseServiceProtocol: Sendable {
    func setLoginData(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws -> String
    func signOut() async throws
    func reauthenticate(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws
    func revokeAndDeleteUser(authorizationCode: String?) async throws
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

    /// Proves recent login with a fresh Apple credential — Firebase requires this
    /// before `delete()`, otherwise it throws `requiresRecentLogin`.
    public func reauthenticate(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthFirebaseServiceError.noCurrentUser
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        try await user.reauthenticate(with: credential)
        Logger.firebaseService.debug("Reauthenticated user for account deletion")
    }

    /// Revokes the Apple token (so the app drops out of the user's Apple ID
    /// settings — App Review requires this for Sign in with Apple) and then
    /// deletes the Firebase auth user. Must run while still authenticated.
    public func revokeAndDeleteUser(authorizationCode: String?) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthFirebaseServiceError.noCurrentUser
        }

        if let authorizationCode {
            do {
                try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
                Logger.firebaseService.debug("Revoked Apple token")
            } catch {
                // Non-fatal: still delete the account even if revocation fails,
                // but surface it — a persistent failure means stale Apple grants.
                Logger.firebaseService.error("Apple token revoke failed: \(error.localizedDescription)")
                await crashLogger.reportToCrashlytics(error: error)
            }
        }

        try await user.delete()
        Logger.firebaseService.info("Deleted Firebase auth user")
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
            let userData = extractUserData(from: appleIDCredential, firebaseUser: firebaseUser)

            // Only proceed if we have name data from Apple (only available on first sign-in)
            let hasNameData = userData.firstName != nil || userData.lastName != nil

            let existingProfile = try await databaseService.getUserProfile(userId: userId)

            if existingProfile == nil {
                // No profile exists - create new one
                await saveNewUserProfile(userId: userId, userData: userData)
            } else if hasNameData {
                // Profile exists but Apple provided name data (first sign-in) - update it
                Logger.firebaseService.debug("Updating existing profile with name data from Apple Sign In")
                await saveNewUserProfile(userId: userId, userData: userData)
            } else {
                Logger.firebaseService.debug("User profile already exists, no new data to update")
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
