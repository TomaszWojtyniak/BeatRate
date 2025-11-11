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
        // Check user credentials first
        do {
            let credentialsValid = try await getSplashUseCase.checkUserCredentials()
            if credentialsValid {
                Logger.splash.info("User credentials are valid")
            } else {
                Logger.splash.info("User credentials invalid or not logged in")
            }
        } catch {
            Logger.splash.error("Error checking user credentials: \(error.localizedDescription)")
        }

        if await getSplashUseCase.isCacheValid() {
            Logger.splash.info("Cache is valid")
            do {
                let cachedSections = try await getSplashUseCase.getCachedSections()
                if !cachedSections.isEmpty {
                    Logger.splash.info("Cache is not empty, finishing loading data")
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
