//
//  SetAccountUseCase.swift
//  AccountUseCases
//
//  Created by Claude on 22/07/2026.
//

import Foundation
import AccountRepository

public protocol SetAccountUseCaseProtocol: Sendable {
    func setFavoriteAlbums(albumIds: [String]) async throws
}

public actor SetAccountUseCase: SetAccountUseCaseProtocol {
    private let accountRepository: AccountRepositoryProtocol

    public init(accountRepository: AccountRepositoryProtocol = AccountRepository.shared) {
        self.accountRepository = accountRepository
    }

    public func setFavoriteAlbums(albumIds: [String]) async throws {
        try await accountRepository.setFavoriteAlbums(albumIds: albumIds)
    }
}
