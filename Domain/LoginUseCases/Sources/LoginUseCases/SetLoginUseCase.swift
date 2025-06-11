//
//  PostLoginUseCase.swift
//  LoginUseCases
//
//  Created by Tomasz Wojtyniak on 11/06/2025.
//

import SwiftUI
import LoginRepository
import AuthenticationServices

public protocol SetLoginUseCaseProtocol: Sendable {
    func setLoginData(authResult: ASAuthorization) async throws
}

public actor SetLoginUseCase: SetLoginUseCaseProtocol {
    private let loginRepository: LoginRepositoryProtocol
    
    public init(loginRepository: LoginRepositoryProtocol = LoginRepository.shared) {
        self.loginRepository = loginRepository
    }
    
    public func setLoginData(authResult: ASAuthorization) async throws {
        try await loginRepository.setLoginData(authResult: authResult)
    }
}
