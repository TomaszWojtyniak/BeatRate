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
        if await getSplashUseCase.areCredentialsValid() {
            Logger.splash.info("User credentials are valid")
        } else {
            Logger.splash.info("User credentials invalid or not logged in")
            return
        }

        if await isCacheValid() {
            Logger.splash.info("Cache is not empty, finishing loading data")
            try? await Task.sleep(for: .milliseconds(600))
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
        } catch {
            self.showError = true
        }
    }
    
    private func isCacheValid() async -> Bool {
        if await getSplashUseCase.isCacheValid() {
            Logger.splash.info("Cache is valid")
            do {
                let cachedSections = try await getSplashUseCase.getCachedSections()
                if !cachedSections.isEmpty {
                    return true
                }
            } catch {
                self.showError = true
                return false
            }
        }
        return false
    }
}
