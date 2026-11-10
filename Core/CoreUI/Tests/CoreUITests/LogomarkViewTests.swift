import Testing
@testable import CoreUI

@MainActor
struct LogomarkViewTests {

    @Test(arguments: [
        (LogomarkView.Style.fullColor, "AppLogomark"),
        (.yellow, "AppYellowLogomark"),
    ])
    func `each style draws its own asset`(style: LogomarkView.Style, assetName: String) {
        #expect(style.assetName == assetName)
    }
}
