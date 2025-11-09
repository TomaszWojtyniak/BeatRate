//
//  SearchRepository.swift
//  SearchRepository
//
//  Created by Tomasz Wojtyniak on 09/11/2025.
//

import Foundation
import Models
import SwiftDataManager

public protocol SearchRepositoryProtocol {
    func getRecentAlbums() async throws -> [AppleMusicAlbumData]
    func saveRecentAlbum(_ album: AppleMusicAlbumData) async throws
    func clearRecentAlbums() async throws
}

@MainActor
public final class SearchRepository: SearchRepositoryProtocol {
    public static let shared = SearchRepository()

    private let swiftDataManager: SwiftDataManager

    public init(swiftDataManager: SwiftDataManager = .shared) {
        self.swiftDataManager = swiftDataManager
    }

    public func getRecentAlbums() async throws -> [AppleMusicAlbumData] {
        return try await swiftDataManager.getRecentAlbums()
    }

    public func saveRecentAlbum(_ album: AppleMusicAlbumData) async throws {
        try await swiftDataManager.saveRecentAlbum(album)
    }

    public func clearRecentAlbums() async throws {
        try await swiftDataManager.clearRecentAlbums()
    }
}
