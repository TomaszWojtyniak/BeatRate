//
//  GetLoginUseCase.swift
//  LoginUseCases
//
//  Created by Tomasz Wojtyniak on 27/05/2025.
//

import SwiftUI
import LoginRepository

public protocol GetLoginUseCaseProtocol: Sendable {
    func getLoginData() async
}

public actor GetLoginUseCase: GetLoginUseCaseProtocol {
    private let loginRepository: LoginRepositoryProtocol
    
    public init(loginRepository: LoginRepositoryProtocol = LoginRepository.shared) {
        self.loginRepository = loginRepository
    }
    
    public func getLoginData() async {
        await loginRepository.getLoginData()
    }
}
