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
        await fetchSectionsData()
    }

    func track(_ event: AnalyticsEvent) {
        analyticsManager.log(event)
    }

    /// Re-runs the whole load — this is what the empty/failed-state buttons call.
    func retry() async {
        analyticsManager.log(.retryTap(screen: .home))
        state = .loading
        await loadInitialData()
    }

    func refreshData() async {
        analyticsManager.log(.pullToRefresh(screen: .home))
        do {
            try await setHomeUseCase.clearCache()
            Logger.home.debug("Cache cleared for refresh")
        } catch {
            Logger.home.error("Failed to clear cache: \(error)")
        }

        await loadInitialData()
    }
    
    private func fetchSectionsData() async {
        var didFail = false
        do {
            let sections = try await self.getHomeUseCase.fetchHomeSections()
            self.homeSections = sections
            Logger.home.debug("Fetched \(sections.count) sections from network")
        } catch let error {
            didFail = true
            Logger.home.error("Failed to fetch sections: \(error)")
            CrashLogger.log("[home] Failed to fetch sections: \(error)")
            self.crashLogger.reportToCrashlytics(error: error)
        }
        state = resolveState(didFail: didFail)
    }

    /// Whatever is already on screen wins: a failed refresh must not blank a feed
    /// the user can still read. Only then does it matter whether the fetch threw —
    /// a request that succeeded and returned nothing is an empty backend, not an
    /// outage, and telling that user to check their connection sends them chasing
    /// a fault that is not there. Missing Apple Music access is gated in `TabBarView`.
    private func resolveState(didFail: Bool) -> HomeState {
        if !homeSections.isEmpty { return .ready }
        return didFail ? .failed : .empty
    }
}

enum HomeState: Equatable {
    case loading
    case ready
    /// The feed could not be loaded — network or backend.
    case failed
    /// The fetch succeeded and there is genuinely nothing to show.
    case empty
}
