import SwiftUI
import Testing
@testable import CoreUI

@MainActor
struct ColorPaletteTests {

    @Test(arguments: await [
        Color.backgroundColor, .primaryText, .secondaryText, .accentSecondary,
        .accentSecondarySoft, .accentSecondaryTint, .errorRed, .surfaceStroke,
    ])
    func `adaptive colour changes between light and dark mode`(color: Color) {
        #expect(color.resolved(in: .light) != color.resolved(in: .dark))
    }

    @Test func `brand honey is E6B655 in both modes`() {
        let honey = Color(hex: "E6B655")

        #expect(Color.accentPrimary.resolved(in: .light) == honey.resolved())
        #expect(Color.accentPrimary.resolved(in: .dark) == honey.resolved())
    }

    @Test(arguments: await [
        (Color.primaryTextOnDark, Color.primaryText),
        (.secondaryTextOnDark, .secondaryText),
    ])
    func `fixed on dark text matches the adaptive text in dark mode`(fixed: Color, adaptive: Color) {
        #expect(fixed.resolved(in: .light) == adaptive.resolved(in: .dark))
    }
}
