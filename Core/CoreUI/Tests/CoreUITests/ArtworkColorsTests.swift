import Foundation
import SwiftUI
import Testing
import UIKit
@testable import CoreUI

@MainActor
struct ArtworkColorsTests {

    private static let red = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
    // Less saturated than red, so the ranking never depends on sort order.
    private static let blue = UIColor(red: 51 / 255, green: 51 / 255, blue: 1, alpha: 1)
    private static let grey = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)

    @Test func `most saturated quadrant is primary and a different hue is secondary`() throws {
        let data = ArtworkFixture.quadrants([Self.red, Self.red, Self.blue, Self.grey])

        let colors = try #require(ArtworkColors.extract(fromImageData: data))

        #expect(colors.primary.resolved() == Color(Self.red).resolved())
        #expect(colors.secondary.resolved() == Color(Self.blue).resolved())
    }

    @Test func `monochrome cover falls back to the runner up`() throws {
        let colors = try #require(ArtworkColors.extract(fromImageData: ArtworkFixture.flat(.black)))

        #expect(colors.primary.resolved() == colors.secondary.resolved())
    }

    @Test func `single pixel cover is too small to split`() {
        #expect(ArtworkColors.extract(fromImageData: ArtworkFixture.flat(Self.red, side: 1)) == nil)
    }

    @Test func `bytes that are not an image give no colours`() {
        #expect(ArtworkColors.extract(fromImageData: Data("not an image".utf8)) == nil)
    }

    @Test func `cover is downloaded from its url`() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).png")
        try ArtworkFixture.flat(Self.red).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let colors = await ArtworkColors.extract(from: url)

        #expect(colors?.primary.resolved() == Color(Self.red).resolved())
    }

    @Test func `unreachable url gives no colours`() async {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).png")

        #expect(await ArtworkColors.extract(from: url) == nil)
    }

    @Test(arguments: [
        ((r: 1.0, g: 0.0, b: 0.0), 1.0),
        ((r: 1.0, g: 0.5, b: 0.5), 0.5),
        ((r: 0.5, g: 0.5, b: 0.5), 0.0),
        ((r: 0.0, g: 0.0, b: 0.0), 0.0),
    ])
    func `saturation is the spread between the strongest and weakest channel`(rgb: (r: Double, g: Double, b: Double), expected: Double) {
        #expect(abs(ArtworkColors.saturation(rgb) - expected) < 1e-9)
    }

    @Test(arguments: [
        ((r: 1.0, g: 0.0, b: 0.0), 0.0),
        ((r: 0.0, g: 1.0, b: 0.0), 1.0 / 3),
        ((r: 0.0, g: 0.0, b: 1.0), 2.0 / 3),
        ((r: 1.0, g: 0.0, b: 1.0), 5.0 / 6),
        ((r: 0.5, g: 0.5, b: 0.5), 0.0),
    ])
    func `hue is placed on the colour wheel from zero to one`(rgb: (r: Double, g: Double, b: Double), expected: Double) {
        #expect(abs(ArtworkColors.hue(rgb) - expected) < 1e-9)
    }
}
