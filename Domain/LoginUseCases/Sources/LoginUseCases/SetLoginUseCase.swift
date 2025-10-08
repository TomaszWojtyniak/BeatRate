//
//  PostLoginUseCase.swift
//  LoginUseCases
//
//  Created by Tomasz Wojtyniak on 11/06/2025.
//

import SwiftUI
import LoginRepository
import AuthenticationServices
import SwiftDataManager

public protocol SetLoginUseCaseProtocol: Sendable {
    func setLoginData(authResult: ASAuthorization) async throws -> String
    func setUserLoggedIn(userId: String) async throws
}

public actor SetLoginUseCase: SetLoginUseCaseProtocol {
    private let loginRepository: LoginRepositoryProtocol
    private let swiftDataManager: SwiftDataManagerProtocol
    
    public init(loginRepository: LoginRepositoryProtocol = LoginRepository.shared,
                swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared) {
        self.loginRepository = loginRepository
        self.swiftDataManager = swiftDataManager
    }
    
    public func setLoginData(authResult: ASAuthorization) async throws -> String {
        return try await loginRepository.setLoginData(authResult: authResult)
    }
    
    public func setUserLoggedIn(userId: String) async throws {
        try await self.swiftDataManager.setUserLoggedIn(userId: userId)
    }
}
