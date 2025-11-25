//
//  GetLoginUseCase.swift
//  LoginUseCases
//
//  Created by Tomasz Wojtyniak on 27/05/2025.
//

import SwiftUI
import LoginRepository
import Models
import AuthenticationServices

public protocol GetLoginUseCaseProtocol: Sendable {
    func getCurrentNonce() async -> String
    func getUserProfile(userId: String) async throws -> FirebaseUserProfile?
}

public actor GetLoginUseCase: GetLoginUseCaseProtocol {
    private let loginRepository: LoginRepositoryProtocol

    public init(loginRepository: LoginRepositoryProtocol = LoginRepository.shared) {
        self.loginRepository = loginRepository
    }

    public func getCurrentNonce() async -> String {
        await self.loginRepository.getCurrentNonce()
    }

    public func getUserProfile(userId: String) async throws -> FirebaseUserProfile? {
        return try await loginRepository.getUserProfile(userId: userId)
    }
}
