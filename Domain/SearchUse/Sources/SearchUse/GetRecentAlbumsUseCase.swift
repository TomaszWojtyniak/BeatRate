//
//  GetRecentAlbumsUseCase.swift
//  SearchUse
//
//  Created by Tomasz Wojtyniak on 09/11/2025.
//

import Foundation
import SearchRepository
import Models

public protocol GetRecentAlbumsUseCaseProtocol {
    func execute() async -> [AppleMusicAlbumData]
}

@MainActor
public final class GetRecentAlbumsUseCase: GetRecentAlbumsUseCaseProtocol {
    private let searchRepository: SearchRepositoryProtocol

    public init(searchRepository: SearchRepositoryProtocol = SearchRepository.shared) {
        self.searchRepository = searchRepository
    }

    public func execute() async -> [AppleMusicAlbumData] {
        do {
            return try await searchRepository.getRecentAlbums()
        } catch {
            // Silent fail - return empty array if error
            return []
        }
    }
}
