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
    func search(searchTerm: String) async throws -> MusicSearchResults
}

public actor GetSearchUseCase: GetSearchUseCaseProtocol {
    let musicRepository: MusicRepositoryProtocol

    public init(musicRepository: MusicRepositoryProtocol = MusicRepository.shared) {
        self.musicRepository = musicRepository
    }

    public func search(searchTerm: String) async throws -> MusicSearchResults {
        guard !searchTerm.isEmpty else {
            return .empty
        }

        return try await self.musicRepository.search(searchTerm: searchTerm)
    }
}
