//
//  SwiftDataManager.swift
//  SwiftDataManager
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftData
import SwiftUI
import Models
import CoreApp
import Analytics
import OSLog

public protocol SwiftDataManagerProtocol: Sendable {
    var context: ModelContext { get }
    func cacheAlbum(id: String, album: AlbumModel) async throws
    func cacheSections(_ sections: [HomeSection]) async throws
    func getCachedSections() async throws -> [HomeSection]
    func getCachedAlbum(id: String) async throws -> AlbumModel?
    func updateCachedAlbum(albumId: String, firebaseData: FirebaseAlbumData) async throws
    func getCachedUserRating(albumId: String) async throws -> Double?
    func cacheUserRating(albumId: String, rating: Double) async throws
    func clearCache() async throws
    func clearAllCacheForLogout() async throws
    func isCacheValid() async -> Bool

    // User management methods
    func getCurrentUser() async throws -> User?
    func getCurrentUserId() async throws -> String?
    func setUserLoggedIn(userId: String) async throws
    func setUserLoggedOut() async throws
    func isUserLoggedIn() async -> Bool
    func observeLoginState() -> AsyncStream<Bool>

    // Recent albums methods
    func getRecentAlbums() async throws -> [AppleMusicAlbumData]
    func saveRecentAlbum(_ album: AppleMusicAlbumData) async throws
    func clearRecentAlbums() async throws
}

@Observable
@MainActor
public final class SwiftDataManager: ObservableObject, SwiftDataManagerProtocol {
    public static let shared = SwiftDataManager()
    public let container: ModelContainer
    private let keychainManager: KeychainManager

    private let loginStateStream: AsyncStream<Bool>
    private let loginStateContinuation: AsyncStream<Bool>.Continuation

    private init(keychainManager: KeychainManager = .shared) {
        self.keychainManager = keychainManager

        // Create AsyncStream for login state changes
        var continuation: AsyncStream<Bool>.Continuation!
        self.loginStateStream = AsyncStream { cont in
            continuation = cont
        }
        self.loginStateContinuation = continuation

        do {
            container = try ModelContainer(for: CachedAlbum.self, CachedSection.self, User.self, RecentAlbum.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    public func observeLoginState() -> AsyncStream<Bool> {
        return loginStateStream
    }
    
    public var context: ModelContext {
        get {
            container.mainContext
        }
    }

    public func clearAllCacheForLogout() async throws {
        try context.delete(model: CachedAlbum.self)
        try context.delete(model: CachedSection.self)
        try context.delete(model: RecentAlbum.self)
        try context.save()
    }
    
    // MARK: - Home sections
    
    public func cacheSections(_ sections: [HomeSection]) async throws {
        // Clear existing sections
        try context.delete(model: CachedSection.self)
        
        for (index, section) in sections.enumerated() {
            let cachedSection = CachedSection(
                sectionId: "section_\(index)",
                name: section.sectionName,
                order: index
            )
            
            var cachedAlbums: [CachedAlbum] = []
            for album in section.albums {
                // Use actual album ID (Apple Music catalog ID)
                let albumId = album.id

                // Check if album already exists
                let descriptor = FetchDescriptor<CachedAlbum>(
                    predicate: #Predicate { $0.id == albumId }
                )

                let existingAlbum = try context.fetch(descriptor).first

                let cachedAlbum = existingAlbum ?? CachedAlbum(
                    id: albumId,
                    appleMusicAlbumData: album.appleMusicAlbumData,
                    firebaseAlbumData: album.firebaseAlbumData
                )

                if existingAlbum == nil {
                    context.insert(cachedAlbum)
                }
                cachedAlbums.append(cachedAlbum)
            }
            
            cachedSection.albums = cachedAlbums
            context.insert(cachedSection)
        }
        
        try context.save()
    }
    
    public func getCachedSections() async throws -> [HomeSection] {
        let descriptor = FetchDescriptor<CachedSection>(
            sortBy: [SortDescriptor(\.order)]
        )
        let sections = try context.fetch(descriptor)
        return sections.map { $0.toHomeSection() }
    }
    
    public func clearCache() async throws {
        try context.delete(model: CachedAlbum.self)
        try context.delete(model: CachedSection.self)
        try context.save()
    }
    
    public func isCacheValid() async -> Bool {
        let descriptor = FetchDescriptor<CachedSection>()
        let sections = try? context.fetch(descriptor)
        
        guard let sections, !sections.isEmpty else { return false }
        
        // Check if cache is less than 24 hours old
        let dayAgo = Date().addingTimeInterval(-86400)
        return sections.allSatisfy { $0.lastUpdated > dayAgo }
    }
    
    // MARK: - Album
    
    public func cacheAlbum(id: String, album: AlbumModel) async throws {
        let cachedAlbum = CachedAlbum(
            id: id,
            appleMusicAlbumData: album.appleMusicAlbumData,
            firebaseAlbumData: album.firebaseAlbumData
        )
        context.insert(cachedAlbum)
        try context.save()
    }
    
    public func getCachedAlbum(id: String) async throws -> AlbumModel? {
        let descriptor = FetchDescriptor<CachedAlbum>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first?.toAlbumModel()
    }

    public func updateCachedAlbum(albumId: String, firebaseData: FirebaseAlbumData) async throws {
        let descriptor = FetchDescriptor<CachedAlbum>(
            predicate: #Predicate { $0.id == albumId }
        )

        guard let cachedAlbum = try context.fetch(descriptor).first else {
            return // Album not in cache, nothing to update
        }

        cachedAlbum.firebaseAlbumData = firebaseData
        // Keep lastUpdated unchanged so cache remains valid
        try context.save()
    }
    
    // MARK: - User rating

    public func getCachedUserRating(albumId: String) async throws -> Double? {
        let descriptor = FetchDescriptor<CachedAlbum>(
            predicate: #Predicate { $0.id == albumId }
        )

        guard let cachedAlbum = try context.fetch(descriptor).first else {
            return nil
        }

        // Check if user rating cache is valid (7 days)
        if let updatedAt = cachedAlbum.userRatingUpdatedAt {
            let sevenDaysAgo = Date().addingTimeInterval(-(7 * 24 * 60 * 60)) // 7 days in seconds
            if updatedAt > sevenDaysAgo {
                return cachedAlbum.userRating
            }
        }

        return nil
    }

    public func cacheUserRating(albumId: String, rating: Double) async throws {
        let descriptor = FetchDescriptor<CachedAlbum>(
            predicate: #Predicate { $0.id == albumId }
        )

        guard let cachedAlbum = try context.fetch(descriptor).first else {
            return // Album not in cache, nothing to update
        }

        cachedAlbum.userRating = rating
        cachedAlbum.userRatingUpdatedAt = Date()
        try context.save()
    }
    
    // MARK: - User Management
    
    public func getCurrentUser() async throws -> User? {
        let descriptor = FetchDescriptor<User>()
        let users = try context.fetch(descriptor)

        // Safety check: If multiple Users exist (shouldn't happen), clean up duplicates
        if users.count > 1 {
            Logger.swiftDataManager.debug("⚠️ SwiftDataManager: Found \(users.count) User models, expected 1. Cleaning up duplicates.")
            // Keep the first one, delete the rest
            for user in users.dropFirst() {
                context.delete(user)
            }
            try context.save()
        }

        return users.first
    }

    public func setUserLoggedIn(userId: String) async throws {
        // Ensure singleton pattern - should only ever be one User
        let descriptor = FetchDescriptor<User>()
        let allUsers = try context.fetch(descriptor)

        if let existingUser = allUsers.first {
            // Update existing user
            existingUser.isLoggedIn = true
            existingUser.userId = userId

            // Clean up any duplicate Users (shouldn't happen, but safety check)
            if allUsers.count > 1 {
                Logger.swiftDataManager.debug("⚠️ SwiftDataManager: Found \(allUsers.count) User models during login, removing duplicates")
                for duplicate in allUsers.dropFirst() {
                    context.delete(duplicate)
                }
            }
        } else {
            // Create new user
            let newUser = User(isLoggedIn: true, userId: userId)
            context.insert(newUser)
        }
        try context.save()

        // Emit login state change to stream
        loginStateContinuation.yield(true)
    }
    
    public func setUserLoggedOut() async throws {
        if let existingUser = try await getCurrentUser() {
            existingUser.isLoggedIn = false
            try context.save()
        }

        // Clear Apple user ID from Keychain
        do {
            try await keychainManager.deleteAppleUserID()
        } catch {
            // Log but don't fail - user is still logged out in SwiftData
            Logger.swiftDataManager.error("Failed to delete Apple user ID from Keychain: \(error)")
        }

        // Clear all cached data
        do {
            try await clearAllCacheForLogout()
        } catch {
            // Log but don't fail - user is still logged out
            Logger.swiftDataManager.error("Failed to clear cache during logout: \(error)")
        }

        // Emit login state change to stream
        loginStateContinuation.yield(false)
    }
    
    public func isUserLoggedIn() async -> Bool {
        guard let user = try? await getCurrentUser() else { return false }
        return user.isLoggedIn
    }

    public func getCurrentUserId() async throws -> String? {
        guard let user = try await getCurrentUser() else { return nil }
        return user.userId
    }

    // MARK: - Recent Albums Management

    public func getRecentAlbums() async throws -> [AppleMusicAlbumData] {
        let descriptor = FetchDescriptor<RecentAlbum>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        let recentAlbums = try context.fetch(descriptor)

        // Return only the first 5
        return Array(recentAlbums.prefix(5)).map { $0.toAppleMusicAlbumData() }
    }

    public func saveRecentAlbum(_ album: AppleMusicAlbumData) async throws {
        // Extract albumId to avoid Sendable issues with Predicate
        let albumId = album.id

        // Check if album already exists
        let descriptor = FetchDescriptor<RecentAlbum>(
            predicate: #Predicate { $0.id == albumId }
        )

        if let existingAlbum = try context.fetch(descriptor).first {
            // Update the addedAt timestamp to move it to the top
            existingAlbum.appleMusicAlbumData = album
            existingAlbum.addedAt = Date()
        } else {
            // Add new recent album
            let recentAlbum = RecentAlbum(id: album.id, appleMusicAlbumData: album)
            context.insert(recentAlbum)
        }

        try context.save()

        // Keep only the most recent 5
        let allDescriptor = FetchDescriptor<RecentAlbum>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        let allRecent = try context.fetch(allDescriptor)

        // Delete albums beyond the first 5
        if allRecent.count > 5 {
            for recentAlbum in allRecent.dropFirst(5) {
                context.delete(recentAlbum)
            }
            try context.save()
        }
    }

    public func clearRecentAlbums() async throws {
        try context.delete(model: RecentAlbum.self)
        try context.save()
    }
}


