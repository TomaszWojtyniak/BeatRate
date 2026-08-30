//
//  SpotifyAuthResult.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 04/03/2026.
//

import Foundation

public nonisolated struct SpotifyAuthResult: Sendable {
    public let isAuthorized: Bool
    public let premium: SpotifyPremiumStatus

    public init(isAuthorized: Bool, premium: SpotifyPremiumStatus) {
        self.isAuthorized = isAuthorized
        self.premium = premium
    }
}
