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

    #expect(withPolish.namePL == "Nowe")
    #expect(englishOnly.namePL == nil)
}
