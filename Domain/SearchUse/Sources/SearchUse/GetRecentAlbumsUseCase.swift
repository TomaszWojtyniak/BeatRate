//
//  GetRecentAlbumsUseCase.swift
//  SearchUse
//
//  Created by Tomasz Wojtyniak on 09/11/2025.
//

import Foundation
import SearchRepository
import Models

public protocol GetRecentAlbumsUseCaseProtocol: Sendable {
    func fetchRecentAlbums() async -> [AppleMusicAlbumData]
}

public actor GetRecentAlbumsUseCase: GetRecentAlbumsUseCaseProtocol {
    private let searchRepository: SearchRepositoryProtocol

    public init(searchRepository: SearchRepositoryProtocol = SearchRepository.shared) {
        self.searchRepository = searchRepository
    }

    public func fetchRecentAlbums() async -> [AppleMusicAlbumData] {
        do {
            return try await searchRepository.getRecentAlbums()
        } catch {
            // Silent fail - return empty array if error
            return []
        }
    }
}
