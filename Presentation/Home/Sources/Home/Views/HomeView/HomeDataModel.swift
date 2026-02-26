//
//  HomeDataModel.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI
import Analytics
import OSLog
import Models
import HomeUseCases

@Observable
@MainActor
final class HomeDataModel {
    private let analyticsManager: AnalyticsManager
    private let crashLogger: CrashLogger
    private let getHomeUseCase: GetHomeUseCaseProtocol
    private let setHomeUseCase: SetHomeUseCaseProtocol
    
    var homeSections: [HomeSection] = []
    var isLoadingFromCache: Bool = false
    
    init(analyticsManager: AnalyticsManager = .shared,
         crashLogger: CrashLogger = .shared,
         getHomeUseCase: GetHomeUseCaseProtocol = GetHomeUseCase(),
         setHomeUseCase: SetHomeUseCaseProtocol = SetHomeUseCase()) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
        self.getHomeUseCase = getHomeUseCase
        self.setHomeUseCase = setHomeUseCase
    }
    
    func loadInitialData() async {
        await authorizeMusicKit()
        await fetchSectionsData()
    }
    
    func authorizeMusicKit() async {
        let musicAuthorizationInfo = await self.getHomeUseCase.authorizeMusicKit()
        Logger.home.debug("MusicKit authorization status: \(musicAuthorizationInfo.isAuthorized)")
    }
    
    func refreshData() async {
        do {
            try await setHomeUseCase.clearCache()
            Logger.home.debug("Cache cleared for refresh")
        } catch {
            Logger.home.error("Failed to clear cache: \(error)")
        }
        
        await fetchSectionsData()
    }
    
    private func fetchSectionsData() async {
        do {
            let sections = try await self.getHomeUseCase.fetchHomeSections()
            self.homeSections = sections
            Logger.home.debug("Fetched \(sections.count) sections from network")
        } catch let error {
            Logger.home.error("Failed to fetch sections: \(error)")
            self.crashLogger.reportToCrashlytics(error: error)
        }
    }
}
