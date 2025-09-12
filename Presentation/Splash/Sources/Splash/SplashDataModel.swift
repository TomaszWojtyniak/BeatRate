//
//  SplashDataModel.swift
//  Splash
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftUI
import SplashUseCases
import Analytics
import OSLog

@Observable
@MainActor
final class SplashDataModel {
    private let getSplashUseCase: GetSplashUseCaseProtocol
    
    var showError: Bool = false
    
    init(getSplashUseCase: GetSplashUseCaseProtocol = GetSplashUseCase()) {
        self.getSplashUseCase = getSplashUseCase
    }
    
    func loadInitialData() async {
        if await getSplashUseCase.isCacheValid() {
            Logger.splash.info("Cache is valid")
            do {
                let cachedSections = try await getSplashUseCase.getCachedSections()
                if !cachedSections.isEmpty {
                    Logger.splash.info("Cache is not empty, finishing loadin data")
                    try? await Task.sleep(for: .milliseconds(600))
                    return
                }
            } catch {
                self.showError = true
                return
            }
        }
        
        let isAuthorized = await getSplashUseCase.authorizeMusicKit()
        
        if !isAuthorized {
            self.showError = true
            return
        }
        
        Logger.splash.info("Music kit is authorized")
        Logger.splash.info("Fetching data")
        
        do {
            let sections = try await getSplashUseCase.fetchHomeSections()
            Logger.splash.info("Data fetched")
            if sections.isEmpty {
                self.showError = true
                return
            }
            Logger.splash.info("Caching data")
            try await getSplashUseCase.cacheSections(sections)
            try? await Task.sleep(for: .milliseconds(600))
            return
        } catch {
            self.showError = true
            return
        }
    }
}
