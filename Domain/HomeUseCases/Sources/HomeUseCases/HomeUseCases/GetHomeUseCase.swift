//
//  GetHomeUseCase.swift
//  HomeUseCases
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Models
import HomeRepository

public protocol GetHomeUseCaseProtocol: Sendable {
    func fetchHomeSections() async throws -> [HomeSection]
}

public actor GetHomeUseCase: GetHomeUseCaseProtocol {
    private let homeRepository: HomeRepositoryProtocol
    
    public init(homeRepository: HomeRepositoryProtocol = HomeRepository.shared) {
        self.homeRepository = homeRepository
    }
    
    public func fetchHomeSections() async throws -> [HomeSection] {
        return try await homeRepository.fetchHomeSections()
    }
    
}
