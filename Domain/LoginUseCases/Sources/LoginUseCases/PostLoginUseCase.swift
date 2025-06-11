//
//  PostLoginUseCase.swift
//  LoginUseCases
//
//  Created by Tomasz Wojtyniak on 11/06/2025.
//

import SwiftUI
import LoginRepository
import AuthenticationServices

public protocol PostLoginUseCaseProtocol: Sendable {
    func postLoginData(authResult: ASAuthorization) async throws
}

public actor PostLoginUseCase: PostLoginUseCaseProtocol {
    private let loginRepository: LoginRepositoryProtocol
    
    public init(loginRepository: LoginRepositoryProtocol = LoginRepository.shared) {
        self.loginRepository = loginRepository
    }
    
    public func postLoginData(authResult: ASAuthorization) async throws {
        try await loginRepository.postLoginData(authResult: authResult)
    }
}
