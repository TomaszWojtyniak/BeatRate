//
//  GetAppUseCase.swift
//  AppUseCases
//
//  Created by Tomasz Wojtyniak on 16/09/2025.
//

import Foundation
import SwiftDataManager
import SwiftData

public protocol GetAppUseCaseProtocol: Sendable {
    @MainActor func context() -> ModelContext
}

public actor GetAppUseCase: GetAppUseCaseProtocol {
    let swiftDataManager: SwiftDataManagerProtocol
    
    public init(swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared) {
        self.swiftDataManager = swiftDataManager
    }
    
    @MainActor public func context() -> ModelContext {
        self.swiftDataManager.context
    }
}
