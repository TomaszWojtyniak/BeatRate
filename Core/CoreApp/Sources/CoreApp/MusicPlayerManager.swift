//
//  MusicPlayerManager.swift
//  CoreApp
//

import Foundation
import Models
import OSLog

private let logger = Logger(subsystem: "com.beatrate.app", category: "musicPlayer")

@Observable
@MainActor
public final class MusicPlayerManager {
    public static let shared = MusicPlayerManager()

    public private(set) var current: MusicPlayer?

    private let userDefaultsManager: UserDefaultsManager

    private init(userDefaultsManager: UserDefaultsManager = .shared) {
        self.userDefaultsManager = userDefaultsManager
    }

    public func hydrate(for userId: String) {
        current = userDefaultsManager.mainMusicPlayer(for: userId)
        logger.debug("Hydrated for user \(userId): \(self.current?.rawValue ?? "nil")")
    }

    public func set(_ player: MusicPlayer, for userId: String) {
        userDefaultsManager.setMainMusicPlayer(player, for: userId)
        current = player
        logger.info("Set to \(player.rawValue) for user \(userId)")
    }

    public func clear(for userId: String) {
        userDefaultsManager.removeMainMusicPlayer(for: userId)
        current = nil
        logger.info("Cleared for user \(userId)")
    }
}
