import SwiftUI
import Testing
@testable import CoreUI

@MainActor
struct ColorHexTests {

    @Test(arguments: [
        ("#E6B655", Color(red: 230 / 255, green: 182 / 255, blue: 85 / 255)),
        ("FFF", Color(red: 1, green: 1, blue: 1)),
        ("80FF0000", Color(red: 1, green: 0, blue: 0, opacity: 128 / 255)),
    ])
    func `hex string is read as rgb, short rgb or argb`(hex: String, expected: Color) {
        #expect(Color(hex: hex).resolved() == expected.resolved())
    }

    @Test func `unsupported hex length falls back to a near invisible colour`() {
        let resolved = Color(hex: "12345").resolved()

        #expect(resolved == Color(red: 1 / 255, green: 1 / 255, blue: 0, opacity: 1 / 255).resolved())
    }
}
