//
//  UserDefaultsManager.swift
//  CoreApp
//

import Foundation
import Models

public nonisolated final class UserDefaultsManager: Sendable {
    public static let shared = UserDefaultsManager()

    /// `nonisolated(unsafe)` is sound here on two grounds: `UserDefaults` is documented
    /// thread-safe, and this property is set once during `init` and never reassigned —
    /// only its underlying read/write methods are invoked, which the system synchronises.
    nonisolated(unsafe) private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func mainMusicPlayerKey(for userId: String) -> String {
        "mainMusicPlayer.\(userId)"
    }

    public func mainMusicPlayer(for userId: String) -> MusicPlayer? {
        guard let raw = defaults.string(forKey: mainMusicPlayerKey(for: userId)) else { return nil }
        return MusicPlayer(rawValue: raw)
    }

    public func setMainMusicPlayer(_ player: MusicPlayer, for userId: String) {
        defaults.set(player.rawValue, forKey: mainMusicPlayerKey(for: userId))
    }

    public func removeMainMusicPlayer(for userId: String) {
        defaults.removeObject(forKey: mainMusicPlayerKey(for: userId))
    }
}
