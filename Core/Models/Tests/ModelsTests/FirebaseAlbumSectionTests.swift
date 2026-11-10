import Foundation
import Testing
@testable import Models

struct FirebaseAlbumSectionTests {

    private static func decode(_ json: String) throws -> FirebaseAlbumSection {
        try JSONDecoder().decode(FirebaseAlbumSection.self, from: Data(json.utf8))
    }

    @Test func `section decodes with its polish title`() throws {
        let section = try Self.decode(#"{"id":"a","name":"New","name_pl":"Nowe","albums":["1","2"],"isActive":true}"#)

        #expect(section.id == "a")
        #expect(section.name == "New")
        #expect(section.namePL == "Nowe")
        #expect(section.albums == ["1", "2"])
        #expect(section.isActive)
    }

    @Test func `missing polish title decodes as nil`() throws {
        #expect(try Self.decode(#"{"id":"b","name":"New","albums":[],"isActive":true}"#).namePL == nil)
    }

    // The console stores a number-looking title as a number; only that field may be lost.
    @Test func `numeric polish title is dropped without failing the section`() throws {
        let section = try Self.decode(#"{"id":"c","name":"2024","name_pl":2024,"albums":[],"isActive":false}"#)

        #expect(section.namePL == nil)
        #expect(section.name == "2024")
    }

    @Test func `section without required fields fails to decode`() {
        #expect(throws: DecodingError.self) { try Self.decode(#"{"id":"d","name":"New"}"#) }
    }

    @Test func `memberwise section has no polish title by default`() {
        let section = FirebaseAlbumSection(id: "e", name: "New", albums: ["1"], isActive: true)

        #expect(section.namePL == nil)
        #expect(section.albums == ["1"])
    }
}
