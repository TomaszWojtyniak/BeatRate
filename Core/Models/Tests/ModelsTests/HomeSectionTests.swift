import Foundation
import Testing
@testable import Models

@MainActor
struct HomeSectionTests {

    @Test(arguments: [
        ("pl", "Nowe" as String?, "Nowe"),
        ("en", "Nowe", "New"),
        (nil, "Nowe", "New"),
        ("pl", "", "New"),
        ("pl", nil, "New"),
    ] as [(String?, String?, String)])
    func `polish title is shown only in polish when one exists`(language: String?, namePL: String?, expected: String) {
        let section = HomeSection(name: "New", namePL: namePL, albums: [])

        #expect(section.title(for: language) == expected)
    }

    @Test func `shown title follows the app language`() {
        let section = HomeSection(name: "New", namePL: "Nowe", albums: [])

        #expect(section.sectionName == section.title(for: Bundle.main.preferredLocalizations.first))
    }

    @Test func `analytics name defaults to the base title`() {
        #expect(HomeSection(name: "New", albums: []).analyticsName == "New")
        #expect(HomeSection(name: "Nowe", analyticsName: "New", albums: []).analyticsName == "New")
    }

    @Test func `sections with the same title are still distinct`() {
        #expect(HomeSection(name: "New", albums: []).id != HomeSection(name: "New", albums: []).id)
    }
}
