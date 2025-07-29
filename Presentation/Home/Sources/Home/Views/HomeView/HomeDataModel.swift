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
class HomeDataModel {
    private let analyticsManager: AnalyticsManager
    private let crashLogger: CrashLogger
    private let getHomeUseCase: GetHomeUseCaseProtocol
    private let setHomeUseCase: SetHomeUseCaseProtocol
    static var logger: Logger {
        return Logger.for(Self.self)
    }
    
    var homeSections: [HomeSection] = [
    ]
    
    init(analyticsManager: AnalyticsManager = .shared,
         crashLogger: CrashLogger = .shared,
         getHomeUseCase: GetHomeUseCaseProtocol = GetHomeUseCase(),
         setHomeUseCase: SetHomeUseCaseProtocol = SetHomeUseCase()) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
        self.getHomeUseCase = getHomeUseCase
        self.setHomeUseCase = setHomeUseCase
    }
    
    func authorizeMusicKit() async {
        let isAuthorized = await self.getHomeUseCase.authorizeMusicKit()
        Self.logger.debug("MusicKit authorization status: \(isAuthorized)")
    }
    
    func getMusicData() async {
        do {
            let album = try await self.getHomeUseCase.getAlbumById("1468058165")
            Self.logger.info("Album title: \(album.title), album artist: \(album.artist)")
            let section = HomeSection(sectionName: "Popular", albums: [album])
            self.homeSections.append(section)
        } catch let error {
            Self.logger.error("Get music data error: \(error)")
            await self.crashLogger.recordError(error)
        }
    }
}
