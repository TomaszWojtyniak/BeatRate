//
//  GetAccountUseCase.swift
//  AccountUseCases
//
//  Created by Tomasz Wojtyniak on 09/01/2026.
//

import SwiftUI
import Models
import AccountRepository
import SwiftDataManager

public protocol GetAccountUseCaseProtocol: Sendable {
    func getCurrentUserId() async throws -> String?
    func getUserRatedAlbums() async throws -> [AlbumModel]
    func getRecentlyListenedAlbums(for player: MusicPlayer) async throws -> [AlbumModel]
    func getAlbumSections(recentlyListenedFor player: MusicPlayer?) async throws -> (rated: [AlbumModel], recentlyListened: [AlbumModel])
    func getFavoriteAlbums() async throws -> [AlbumModel]
}

public actor GetAccountUseCase: GetAccountUseCaseProtocol {
    private let accountRepository: AccountRepositoryProtocol
    private let swiftDataManager: SwiftDataManagerProtocol

    public init(accountRepository: AccountRepositoryProtocol = AccountRepository.shared,
                swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared) {
        self.accountRepository = accountRepository
        self.swiftDataManager = swiftDataManager
    }

    public func getCurrentUserId() async throws -> String? {
        return try await swiftDataManager.getCurrentUserId()
    }

    public func getUserRatedAlbums() async throws -> [AlbumModel] {
        return try await accountRepository.getUserRatedAlbums()
    }

    public func getRecentlyListenedAlbums(for player: MusicPlayer) async throws -> [AlbumModel] {
        return try await accountRepository.getRecentlyListenedAlbums(for: player)
    }

    public func getAlbumSections(recentlyListenedFor player: MusicPlayer?) async throws -> (rated: [AlbumModel], recentlyListened: [AlbumModel]) {
        return try await accountRepository.getAlbumSections(recentlyListenedFor: player)
    }

    public func getFavoriteAlbums() async throws -> [AlbumModel] {
        return try await accountRepository.getFavoriteAlbums()
    }
}
