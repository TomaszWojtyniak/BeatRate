import Composition
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

    @Test func `a null in a later file removes the key`() throws {
        let merged = try fixtures(#"{"db":{"albums":{"1":{"title":"A"},"2":{"title":"B"}}}}"#, #"{"db":{"albums":{"1":null}}}"#)

        #expect(merged.value(at: "db/albums/1") == nil)
        #expect(merged.value(at: "db/albums/2/title") as? String == "B")
    }

    @Test func `a null with nothing under it to remove is simply absent`() async throws {
        let merged = try fixtures(#"{"music":{"albums":{"1":null}},"device":{"defaults":{"x":null}}}"#)

        #expect(merged.value(at: "music/albums") as? [String: Any] != nil)
        #expect(merged.value(at: "music/albums/1") == nil)
        _ = try await Edges.fixtures(merged)
    }

    @Test(arguments: [
        (#"{"http":{}}"#, "http"),
        (#"{"device":{"appleIdState":"revoked"}}"#, "device/appleIdState"),
        (#"{"music":{"authorisation":"denied"}}"#, "music/authorisation"),
        (#"{"dbFailures":{"read":["sections"]}}"#, "dbFailures/read"),
        (#"{"timing":{"retryDelay":300}}"#, "timing/retryDelay"),
    ])
    func `an unknown key is refused by its path`(json: String, path: String) async throws {
        await #expect { _ = try await Edges.fixtures(try fixtures(json)) } throws: { "\($0)".contains("unknown key \(path)") }
    }

    @Test(arguments: [
        (#"{"music":{"authorization":"refused"}}"#, "music/authorization"),
        (#"{"music":{"answer":"Denied"}}"#, "music/answer"),
        (#"{"device":{"appleIDState":"gone"}}"#, "device/appleIDState"),
    ])
    func `an unknown value is refused by its path`(json: String, path: String) async throws {
        await #expect { _ = try await Edges.fixtures(try fixtures(json)) } throws: { "\($0)".contains("\(path): unknown value") }
    }

    @Test(arguments: [
        (#"{"timing":{"retryDelayMs":"300"}}"#, "timing/retryDelayMs"),
        (#"{"dbDelayMs":50.5}"#, "dbDelayMs"),
        (#"{"music":{"subscription":"true"}}"#, "music/subscription"),
        (#"{"device":{"firebaseUid":1}}"#, "device/firebaseUid"),
        (#"{"dbFailures":{"reads":"sections"}}"#, "dbFailures/reads"),
        (#"{"device":{"defaults":[]}}"#, "device/defaults"),
    ])
    func `a value of the wrong type is refused by its path`(json: String, path: String) async throws {
        await #expect { _ = try await Edges.fixtures(try fixtures(json)) } throws: { "\($0)".contains("\(path): expected") }
    }

    @Test func `a file that is not a json object names the file`() {
        let path = fixtureFile("[1, 2]")

        #expect { try Fixtures.load([path]) } throws: { "\($0)".contains(path) }
    }

    @Test func `every behavior fixture builds the edges`() async throws {
        let directory = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../../../behavior/fixtures")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }

        #expect(files.count >= 9)
        for file in files {
            _ = try await Edges.fixtures(try Fixtures.load([file.path]))
        }
    }
}
