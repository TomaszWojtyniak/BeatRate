//
//  LoginRepository.swift
//  LoginRepository
//
//  Created by Tomasz Wojtyniak on 27/05/2025.
//

import SwiftUI

public protocol LoginRepositoryProtocol: Sendable {
    func getLoginData() async
}

public actor LoginRepository: LoginRepositoryProtocol {
    public static let shared = LoginRepository()
    
    private init() {
        
    }
    
    public func getLoginData() async {
        
    }
}
