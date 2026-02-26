//
//  ClearRecentAlbumsUseCase.swift
//  SearchUse
//
//  Created by Claude on 09/11/2025.
//

import Foundation
import SearchRepository
import Models

public protocol ClearRecentAlbumsUseCaseProtocol: Sendable {
    func clearAll() async
}

public actor ClearRecentAlbumsUseCase: ClearRecentAlbumsUseCaseProtocol {
    private let searchRepository: SearchRepositoryProtocol

    public init(searchRepository: SearchRepositoryProtocol = SearchRepository.shared) {
        self.searchRepository = searchRepository
    }

    public func clearAll() async {
        do {
            try await searchRepository.clearRecentAlbums()
        } catch {
            // Silent fail - not critical if clearing fails
        }
    }
}
