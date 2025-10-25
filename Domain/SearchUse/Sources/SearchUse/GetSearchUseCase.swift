//
//  GetSearchUseCase.swift
//  SearchUse
//
//  Created by Tomasz Wojtyniak on 16/09/2025.
//

import Foundation
import MusicRepository
import Models

public protocol GetSearchUseCaseProtocol: Sendable {
    func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData]
}

public actor GetSearchUseCase: GetSearchUseCaseProtocol {
    let musicRepository: MusicRepositoryProtocol

    public init(musicRepository: MusicRepositoryProtocol = MusicRepository.shared) {
        self.musicRepository = musicRepository
    }

    public func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData] {
        guard !searchTerm.isEmpty else {
            return []
        }

        return try await self.musicRepository.searchAlbums(searchTerm: searchTerm)
    }
}
