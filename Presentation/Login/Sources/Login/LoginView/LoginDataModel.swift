//
//  LoginDataModel.swift
//  Login
//
//  Created by Tomasz Wojtyniak on 27/05/2025.
//

import SwiftUI
import LoginUseCases

@Observable
@MainActor
class LoginDataModel {
    private let getLoginUseCase: GetLoginUseCaseProtocol
    
    init(getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase()) {
        self.getLoginUseCase = getLoginUseCase
    }
    
    func getLoginData() async {
        await self.getLoginUseCase.getLoginData()
    }
}

