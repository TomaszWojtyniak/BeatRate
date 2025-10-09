//
//  SwiftDataManager.swift
//  SwiftDataManager
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftData
import SwiftUI
import Models

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
    func isCacheValid() async -> Bool

    // User management methods
    func getCurrentUser() async throws -> User?
    func getCurrentUserId() async throws -> String?
    func setUserLoggedIn(userId: String) async throws
    func setUserLoggedOut() async throws
    func isUserLoggedIn() async -> Bool
}

@Observable
@MainActor
public final class SwiftDataManager: ObservableObject, SwiftDataManagerProtocol {
    public static let shared = SwiftDataManager()
    public let container: ModelContainer
    
    private init() {
        do {
            container = try ModelContainer(for: CachedAlbum.self, CachedSection.self, User.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    public var context: ModelContext {
        get {
            container.mainContext
        }
    }
    
    public func cacheAlbum(id: String, album: AlbumModel) async throws {
        let cachedAlbum = CachedAlbum(
            id: id,
            appleMusicAlbumData: album.appleMusicAlbumData,
            firebaseAlbumData: album.firebaseAlbumData
        )
        context.insert(cachedAlbum)
        try context.save()
    }
    
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
    
    // MARK: - User Management
    
    public func getCurrentUser() async throws -> User? {
        let descriptor = FetchDescriptor<User>()
        return try context.fetch(descriptor).first
    }
    
    public func setUserLoggedIn(userId: String) async throws {
        if let existingUser = try await getCurrentUser() {
            existingUser.isLoggedIn = true
            existingUser.userId = userId
        } else {
            let newUser = User(isLoggedIn: true, userId: userId)
            context.insert(newUser)
        }
        try context.save()
    }
    
    public func setUserLoggedOut() async throws {
        if let existingUser = try await getCurrentUser() {
            existingUser.isLoggedIn = false
            try context.save()
        }
    }
    
    public func isUserLoggedIn() async -> Bool {
        guard let user = try? await getCurrentUser() else { return false }
        return user.isLoggedIn
    }

    public func getCurrentUserId() async throws -> String? {
        guard let user = try await getCurrentUser() else { return nil }
        return user.userId
    }
}


