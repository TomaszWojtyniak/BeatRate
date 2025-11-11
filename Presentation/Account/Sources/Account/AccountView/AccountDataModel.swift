//
//  AccountDataModel.swift
//  Account
//
//  Created by Tomasz Wojtyniak on 11/11/2025.
//

import SwiftUI
import LoginUseCases
import Models
import OSLog

@MainActor
@Observable
final class AccountDataModel {
    private let getLoginUseCase: GetLoginUseCaseProtocol

    var errorMessage: String?

    init(getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase()) {
        self.getLoginUseCase = getLoginUseCase
    }

    func loadUserProfile() async {

    }
}
