//
//  HomeSection.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI

public struct HomeSection: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let sectionName: String
    /// Stable English name sent to analytics, so a translated `sectionName`
    /// doesn't split events by language. Defaults to `sectionName`.
    public let analyticsName: String
    /// Firebase's `name_pl`, kept next to the English name so the cache can
    /// pick the title again in whatever language the app runs in next time.
    public let namePL: String?
    public let albums: [AlbumModel]

    /// When the app runs in Polish, a non-empty `namePL` replaces `sectionName` on screen.
    public init(sectionName: String, analyticsName: String? = nil, namePL: String? = nil, albums: [AlbumModel]) {
        if Bundle.main.preferredLocalizations.first == "pl", let namePL, !namePL.isEmpty {
            self.sectionName = namePL
        } else {
            self.sectionName = sectionName
        }
        self.analyticsName = analyticsName ?? sectionName
        self.namePL = namePL
        self.albums = albums
    }
}
