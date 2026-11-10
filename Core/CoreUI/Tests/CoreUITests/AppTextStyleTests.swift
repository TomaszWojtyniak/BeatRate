import SwiftUI
import Testing
@testable import CoreUI

@MainActor
struct AppTextStyleTests {

    @Test func `every role has its own font`() {
        #expect(Set(AppTextStyle.allCases.map(\.font)).count == AppTextStyle.allCases.count)
    }

    @Test(arguments: AppTextStyle.allCases)
    func `only captions, labels and version strings default to secondary text`(style: AppTextStyle) {
        let isMetadata = [AppTextStyle.caption, .mono, .label].contains(style)

        #expect(style.color == (isMetadata ? .secondaryText : .primaryText))
    }

    @Test(arguments: AppTextStyle.allCases)
    func `only uppercased labels widen letter spacing`(style: AppTextStyle) {
        #expect((style.tracking > 0) == (style == .label))
    }

    @Test func `bigger display titles pull tighter`() {
        let titles: [AppTextStyle] = [.displayHero, .displayLarge, .title, .displayName, .titleSection]

        #expect(titles.map(\.tracking) == titles.map(\.tracking).sorted())
    }
}
