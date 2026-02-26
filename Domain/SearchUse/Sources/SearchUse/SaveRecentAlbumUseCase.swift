//
//  SaveRecentAlbumUseCase.swift
//  SearchUse
//
//  Created by Tomasz Wojtyniak on 09/11/2025.
//

import Foundation
import SearchRepository
import Models

public protocol SaveRecentAlbumUseCaseProtocol: Sendable {
    func save(album: AppleMusicAlbumData) async
}

public actor SaveRecentAlbumUseCase: SaveRecentAlbumUseCaseProtocol {
    private let searchRepository: SearchRepositoryProtocol

    public init(searchRepository: SearchRepositoryProtocol = SearchRepository.shared) {
        self.searchRepository = searchRepository
    }

    public func save(album: AppleMusicAlbumData) async {
        do {
            try await searchRepository.saveRecentAlbum(album)
        } catch {
            // Silent fail - not critical if saving recent album fails
        }
    }
}
