import Foundation
import Testing
@testable import BeatRateFixtures

struct FixturesTests {
    @Test func `later files win leaf by leaf and the db tree merges down to its leaves`() throws {
        let merged = try fixtures(
            #"{"db":{"albums":{"1":{"title":"A","artist":"X"}}},"music":{"authorization":"denied"}}"#,
            #"{"db":{"albums":{"1":{"title":"B"},"2":{"title":"C"}}},"music":{"authorization":"authorized"}}"#
        )

        #expect(merged.value(at: "db/albums/1/title") as? String == "B")
        #expect(merged.value(at: "db/albums/1/artist") as? String == "X")
        #expect(merged.value(at: "db/albums/2/title") as? String == "C")
        #expect(merged.value(at: "music/authorization") as? String == "authorized")
        #expect(merged.value(at: "db/albums/3") == nil)
    }

    @Test func `a file that is not a json object names the file`() {
        let path = fixtureFile("[1, 2]")

        #expect { try Fixtures.load([path]) } throws: { "\($0)".contains(path) }
    }
}
