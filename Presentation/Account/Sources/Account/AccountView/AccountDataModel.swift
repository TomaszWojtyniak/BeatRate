//
//  AccountDataModel.swift
//  Account
//
//  Created by Tomasz Wojtyniak on 11/11/2025.
//

import SwiftUI
import LoginUseCases
import AccountUseCases
import Models
import OSLog

@MainActor
@Observable
final class AccountDataModel {
    private let getLoginUseCase: GetLoginUseCaseProtocol
    private let setLoginUseCase: SetLoginUseCaseProtocol
    private let getAccountUseCase: GetAccountUseCaseProtocol

    var userProfile: FirebaseUserProfile?
    var ratedAlbums: [AlbumModel] = []
    var isLoading = false
    var isShowingEditSheet = false
    var errorMessage: String?
    var isShowingAlbumRatingsSection: Bool = false

    var fullName: String? {
        guard let firstName = userProfile?.firstName,
              let lastName = userProfile?.lastName else { return nil }
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    init(getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
         setLoginUseCase: SetLoginUseCaseProtocol = SetLoginUseCase(),
         getAccountUseCase: GetAccountUseCaseProtocol = GetAccountUseCase()) {
        self.getLoginUseCase = getLoginUseCase
        self.setLoginUseCase = setLoginUseCase
        self.getAccountUseCase = getAccountUseCase
    }

    func loadUserData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Get user ID
            guard let userId = try await getAccountUseCase.getCurrentUserId() else {
                Logger.account.error("No user ID found")
                return
            }

            // Fetch user profile and rated albums in parallel
            async let profileTask = getLoginUseCase.getUserProfile(userId: userId)
            async let ratedAlbumsTask = getAccountUseCase.getUserRatedAlbums()

            let (profile, albums) = try await (profileTask, ratedAlbumsTask)

            self.userProfile = profile
            self.ratedAlbums = albums
            
            if self.ratedAlbums.isEmpty {
                self.isShowingAlbumRatingsSection = false
            } else {
                self.isShowingAlbumRatingsSection = true
            }

            Logger.account.info("Loaded user profile and \(albums.count) rated albums")
        } catch {
            Logger.account.error("Failed to load user data: \(error)")
            errorMessage = "Failed to load user data"
        }
    }

    func saveUserProfile(firstName: String, lastName: String) async {
        do {
            guard let userId = try await getAccountUseCase.getCurrentUserId() else {
                Logger.account.error("No user ID found")
                return
            }

            let updatedProfile = FirebaseUserProfile(
                email: userProfile?.email,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                hasAppleMusicSubscription: userProfile?.hasAppleMusicSubscription
            )

            try await setLoginUseCase.saveUserProfile(userId: userId, profile: updatedProfile)
            self.userProfile = updatedProfile
            Logger.account.info("User profile updated successfully")
        } catch {
            Logger.account.error("Failed to save user profile: \(error)")
            errorMessage = "Failed to save profile"
        }
    }
}
