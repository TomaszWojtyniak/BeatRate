//
//  MusicPlayerManager.swift
//  CoreApp
//

import Foundation
import Models
import Analytics
import OSLog

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
        Logger.musicPlayer.debug("Hydrated for user \(userId): \(self.current?.rawValue ?? "nil")")
    }

    public func set(_ player: MusicPlayer, for userId: String) {
        userDefaultsManager.setMainMusicPlayer(player, for: userId)
        current = player
        Logger.musicPlayer.info("Set to \(player.rawValue) for user \(userId)")
    }

    public func clear(for userId: String) {
        userDefaultsManager.removeMainMusicPlayer(for: userId)
        current = nil
        Logger.musicPlayer.info("Cleared for user \(userId)")
    }
}
