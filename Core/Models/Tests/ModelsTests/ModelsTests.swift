import Foundation
import Testing
@testable import Models

/// Firebase sections may or may not carry `name_pl`; both shapes must decode.
@Test func firebaseSectionDecodesOptionalPolishName() throws {
    let decode = { (json: String) throws -> FirebaseAlbumSection in
        try JSONDecoder().decode(FirebaseAlbumSection.self, from: Data(json.utf8))
    }

    let withPolish = try decode(#"{"id":"a","name":"New","name_pl":"Nowe","albums":[],"isActive":true}"#)
    let englishOnly = try decode(#"{"id":"b","name":"New","albums":[],"isActive":true}"#)
    // The console stores a number-looking title as a number; only that field is lost.
    let numeric = try decode(#"{"id":"c","name":"2024","name_pl":2024,"albums":[],"isActive":true}"#)

    #expect(withPolish.namePL == "Nowe")
    #expect(englishOnly.namePL == nil)
    #expect(numeric.namePL == nil)
    #expect(numeric.name == "2024")
}

/// The Polish title shows only in Polish and only when non-empty; analytics and
/// the cache always keep the English name, so a cached section re-picks per language.
@MainActor
@Test func sectionTitleFollowsAppLanguage() {
    let section = HomeSection(name: "New", namePL: "Nowe", albums: [])
    #expect(section.title(for: "pl") == "Nowe")
    #expect(section.title(for: "en") == "New")
    #expect(section.analyticsName == "New")
    #expect(HomeSection(name: "New", namePL: "", albums: []).title(for: "pl") == "New")

    let cached = CachedSection(sectionId: "s", name: section.name, namePL: section.namePL, order: 0).toHomeSection()
    #expect(cached.title(for: "pl") == "Nowe")
    #expect(cached.title(for: "en") == "New")
}
