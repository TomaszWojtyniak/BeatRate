//
//  HomeSection.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI

public struct HomeSection: Identifiable, Hashable, Sendable {
    public let id = UUID()
    /// Base title: English for Firebase sections, already localized for the
    /// sections the app builds itself (Account, Artist).
    public let name: String
    /// Firebase's `name_pl`, shown instead of `name` when the app runs in Polish.
    public let namePL: String?
    /// Stable English name sent to analytics, so a translated title doesn't
    /// split events by language. Defaults to `name`.
    public let analyticsName: String
    public let albums: [AlbumModel]

    public init(name: String, analyticsName: String? = nil, namePL: String? = nil, albums: [AlbumModel]) {
        self.name = name
        self.analyticsName = analyticsName ?? name
        self.namePL = namePL
        self.albums = albums
    }

    /// The title to show, picked for the language the app runs in.
    public var sectionName: String { title(for: Bundle.main.preferredLocalizations.first) }

    func title(for language: String?) -> String {
        if language == "pl", let namePL, !namePL.isEmpty { return namePL }
        return name
    }
}
