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
    var state: HomeState = .loading
    
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
        let isAuthorized = await authorizeMusicKit()
        await fetchSectionsData(isMusicAuthorized: isAuthorized)
    }

    /// Re-runs the whole load, including the authorization check — this is what
    /// the empty-state buttons call, so someone returning from Settings having
    /// just granted access gets a populated feed without relaunching.
    func retry() async {
        state = .loading
        await loadInitialData()
    }

    @discardableResult
    func authorizeMusicKit() async -> Bool {
        let musicAuthorizationInfo = await self.getHomeUseCase.authorizeMusicKit()
        Logger.home.debug("MusicKit authorization status: \(musicAuthorizationInfo.isAuthorized)")
        return musicAuthorizationInfo.isAuthorized
    }
    
    func refreshData() async {
        do {
            try await setHomeUseCase.clearCache()
            Logger.home.debug("Cache cleared for refresh")
        } catch {
            Logger.home.error("Failed to clear cache: \(error)")
        }

        await loadInitialData()
    }
    
    private func fetchSectionsData(isMusicAuthorized: Bool) async {
        var didFail = false
        do {
            let sections = try await self.getHomeUseCase.fetchHomeSections()
            self.homeSections = sections
            Logger.home.debug("Fetched \(sections.count) sections from network")
        } catch let error {
            didFail = true
            Logger.home.error("Failed to fetch sections: \(error)")
            self.crashLogger.reportToCrashlytics(error: error)
        }
        state = resolveState(isMusicAuthorized: isMusicAuthorized, didFail: didFail)
    }

    /// Whatever is already on screen wins: a failed refresh must not blank a feed
    /// the user can still read. Below that, an empty feed without Apple Music
    /// access is almost always the permission, since every album's metadata comes
    /// from MusicKit. Only then does it matter whether the fetch threw — a request
    /// that succeeded and returned nothing is an empty backend, not an outage, and
    /// telling that user to check their connection sends them chasing a fault that
    /// is not there.
    private func resolveState(isMusicAuthorized: Bool, didFail: Bool) -> HomeState {
        if !homeSections.isEmpty { return .ready }
        if !isMusicAuthorized { return .needsAppleMusicAccess }
        return didFail ? .failed : .empty
    }
}

enum HomeState: Equatable {
    case loading
    case ready
    /// MusicKit was refused, so there is no album metadata to render.
    case needsAppleMusicAccess
    /// Authorized, but the feed could not be loaded — network or backend.
    case failed
    /// The fetch succeeded and there is genuinely nothing to show.
    case empty
}
