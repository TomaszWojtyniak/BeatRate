//
//  GetAccountUseCase.swift
//  AccountUseCases
//
//  Created by Tomasz Wojtyniak on 09/01/2026.
//

import SwiftUI
import Models
import HomeRepository
import SwiftDataManager

public protocol GetAccountUseCaseProtocol: Sendable {
    func getCurrentUserId() async throws -> String?
    func getUserRatedAlbums() async throws -> [AlbumModel]
}

public actor GetAccountUseCase: GetAccountUseCaseProtocol {
    private let homeRepository: HomeRepositoryProtocol
    private let swiftDataManager: SwiftDataManagerProtocol

    public init(homeRepository: HomeRepositoryProtocol = HomeRepository.shared,
                swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared) {
        self.homeRepository = homeRepository
        self.swiftDataManager = swiftDataManager
    }

    public func getCurrentUserId() async throws -> String? {
        return try await swiftDataManager.getCurrentUserId()
    }

    public func getUserRatedAlbums() async throws -> [AlbumModel] {
        return try await homeRepository.getUserRatedAlbums()
    }
}
