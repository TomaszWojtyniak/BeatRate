//
//  SpotifyAuthResult.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 04/03/2026.
//

import Foundation

public nonisolated struct SpotifyAuthResult: Sendable {
    public let isAuthorized: Bool
    public let hasSpotifyPremium: Bool

    public init(isAuthorized: Bool, hasSpotifyPremium: Bool) {
        self.isAuthorized = isAuthorized
        self.hasSpotifyPremium = hasSpotifyPremium
    }
}
