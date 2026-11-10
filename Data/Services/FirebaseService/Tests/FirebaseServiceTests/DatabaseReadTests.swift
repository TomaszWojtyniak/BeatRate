import Foundation
import Models
import Testing
@testable import FirebaseService

@MainActor
struct DatabaseReadTests {

    private static func section(_ id: String, active: Bool = true) -> [String: Any] {
        ["id": id, "name": "Section \(id)", "albums": ["1"], "isActive": active]
    }

    @Test func `only active sections come back sorted by id`() async throws {
        let database = FakeRealtimeDatabase(DatabaseValue(["sections": [
            "k1": Self.section("b"), "k2": Self.section("a"), "k3": Self.section("c", active: false),
        ]]))

        let sections = try await makeDatabaseService(database).fetchSections()

        #expect(sections.map(\.id) == ["a", "b"])
    }

    @Test func `missing sections node reads as no sections`() async throws {
        #expect(try await makeDatabaseService(FakeRealtimeDatabase()).fetchSections().isEmpty)
    }

    @Test(arguments: [
        ["name": "No id", "albums": [String](), "isActive": true],
        ["id": "x", "name": "Bad flag", "albums": [String](), "isActive": "yes"],
        ["id": "x", "name": NSNull(), "albums": [String](), "isActive": true],
    ] as [[String: Any & Sendable]])
    func `malformed section fails the whole fetch`(section: [String: Any & Sendable]) async {
        let database = FakeRealtimeDatabase(DatabaseValue(["sections": ["k": section]]))

        await #expect(throws: DecodingError.self) { try await makeDatabaseService(database).fetchSections() }
    }

    @Test func `read failure is passed on`() async {
        let database = FakeRealtimeDatabase(failingReads: ["sections"])

        await #expect(throws: StubError.self) { try await makeDatabaseService(database).fetchSections() }
    }

    @Test func `album community data decodes from its node`() async throws {
        let database = FakeRealtimeDatabase(DatabaseValue(["albums": ["a": ["artist": "Artist", "title": "Album", "avgRating": 7.5, "ratingCount": 2]]]))
        let service = makeDatabaseService(database)

        let album = try await service.fetchAlbumData(albumId: "a")

        #expect(album?.avgRating == 7.5)
        #expect(album?.ratingCount == 2)
        #expect(try await service.fetchAlbumData(albumId: "missing") == nil)
    }

    @Test func `profile decodes from its node`() async throws {
        let database = FakeRealtimeDatabase(DatabaseValue(["users": ["u": ["profile": ["email": "a@b.c", "mainMusicPlayer": "spotify"]]]]))
        let service = makeDatabaseService(database)

        let profile = try await service.getUserProfile(userId: "u")

        #expect(profile?.email == "a@b.c")
        #expect(profile?.mainMusicPlayer == "spotify")
        #expect(try await service.getUserProfile(userId: "missing") == nil)
    }
}
