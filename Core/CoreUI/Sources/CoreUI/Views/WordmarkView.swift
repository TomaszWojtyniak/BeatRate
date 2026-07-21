//
//  WordmarkView.swift
//  CoreUI
//

import SwiftUI

/// The "BeatRate" wordmark, sized to `Size.wordmark`.
///
/// - Important: `AppNameLogomark` ships a light and a dark variant, and iOS picks
///   between them on the *device's* appearance. Every screen that shows the
///   wordmark sits on `Color.backgroundGradient`, which is hard-coded navy and
///   ignores appearance entirely — so on a device in light mode the light variant
///   (near-black "Beat") would land on a dark background and all but vanish. This
///   pins the dark variant so the two can't disagree. Don't remove the
///   `colorScheme` override without also making the backdrop adaptive.
public struct WordmarkView: View {
    public init() {}

    public var body: some View {
        Image("AppNameLogomark")
            .resizable()
            .scaledToFit()
            .environment(\.colorScheme, .dark)
            .accessibilityLabel("BeatRate")
    }
}
