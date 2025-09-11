//
//  SwiftDataManager.swift
//  SwiftDataManager
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftData
import SwiftUI
import Models

@Observable
@MainActor
public final class SwiftDataManager: ObservableObject {
    public static let shared = SwiftDataManager()
    
    public let container: ModelContainer
    public var isDataLoaded = false
    
    private init() {
        do {
            container = try ModelContainer(for: CachedAlbum.self, CachedSection.self, User.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    public var context: ModelContext {
        container.mainContext
    }
    
    public func cacheAlbum(albumId: String, album: AlbumModel) async throws {
        let cachedAlbum = CachedAlbum(
            albumId: albumId,
            title: album.title,
            artist: album.artist,
            coverUrlString: album.coverUrl?.absoluteString,
            releaseDate: album.releaseDate,
            genre: album.genre,
            rating: album.rating
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
                // Generate albumId from title and artist
                let albumId = "\(album.title)_\(album.artist)".replacingOccurrences(of: " ", with: "_")
                
                // Check if album already exists
                let descriptor = FetchDescriptor<CachedAlbum>(
                    predicate: #Predicate { $0.albumId == albumId }
                )
                
                let existingAlbum = try context.fetch(descriptor).first
                
                let cachedAlbum = existingAlbum ?? CachedAlbum(
                    albumId: albumId,
                    title: album.title,
                    artist: album.artist,
                    coverUrlString: album.coverUrl?.absoluteString,
                    releaseDate: album.releaseDate,
                    genre: album.genre,
                    rating: album.rating
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
        isDataLoaded = true
    }
    
    public func getCachedSections() async throws -> [HomeSection] {
        let descriptor = FetchDescriptor<CachedSection>(
            sortBy: [SortDescriptor(\.order)]
        )
        let sections = try context.fetch(descriptor)
        return sections.map { $0.toHomeSection() }
    }
    
    public func getCachedAlbum(albumId: String) async throws -> AlbumModel? {
        let descriptor = FetchDescriptor<CachedAlbum>(
            predicate: #Predicate { $0.albumId == albumId }
        )
        return try context.fetch(descriptor).first?.toAlbumModel()
    }
    
    public func clearCache() async throws {
        try context.delete(model: CachedAlbum.self)
        try context.delete(model: CachedSection.self)
        try context.save()
        isDataLoaded = false
    }
    
    public func isCacheValid() async -> Bool {
        let descriptor = FetchDescriptor<CachedSection>()
        let sections = try? context.fetch(descriptor)
        
        guard let sections, !sections.isEmpty else { return false }
        
        // Check if cache is less than 24 hours old
        let dayAgo = Date().addingTimeInterval(-86400)
        return sections.allSatisfy { $0.lastUpdated > dayAgo }
    }
}


