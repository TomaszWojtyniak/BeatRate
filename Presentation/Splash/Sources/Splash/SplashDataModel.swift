//
//  SplashDataModel.swift
//  Splash
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftUI
import SplashUseCases

@Observable
@MainActor
final class SplashDataModel {
    private let getSplashUseCase: GetSplashUseCaseProtocol
    
    init(getSplashUseCase: GetSplashUseCaseProtocol = GetSplashUseCase()) {
        self.getSplashUseCase = getSplashUseCase
    }
    
    func loadInitialData() async {
        
        if await getSplashUseCase.isCacheValid() {
            do {
                let cachedSections = try await getSplashUseCase.getCachedSections()
            } catch {
                
            }
        }
        
        let isAuthorized = await getSplashUseCase.authorizeMusicKit()
        do {
            let sections = try await getSplashUseCase.fetchHomeSections()
            
            if sections.isEmpty {
                return
            }
            
            try await getSplashUseCase.cacheSections(sections)
            try? await Task.sleep(for: .milliseconds(600))
        } catch {
            
        }
    }
}
