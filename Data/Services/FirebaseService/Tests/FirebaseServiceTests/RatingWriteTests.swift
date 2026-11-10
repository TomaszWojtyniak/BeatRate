import Foundation
import Testing
@testable import FirebaseService

@MainActor
struct RatingWriteTests {

    @Test func `rating a new album creates it and stores both sides of the rating`() async throws {
        let database = FakeRealtimeDatabase()
        let service = makeDatabaseService(database, now: Date(timeIntervalSince1970: 1_234))

        let stats = try await service.saveUserRating(userId: "u", albumId: "a", rating: 8, albumMetadata: (artist: "Artist", title: "Album"))

        #expect(stats == (avgRating: 8, ratingCount: 1))
        #expect(await database.value("users/u/user_ratings/a/rating").raw as? Double == 8)
        #expect(await database.value("users/u/user_ratings/a/timestamp").raw as? Double == 1_234)
        #expect(await database.value("album_ratings/a/u").raw as? Double == 8)
        #expect(await database.value("albums/a/title").raw as? String == "Album")
        #expect(await database.value("albums/a/createdAt").raw as? [String: String] == [".sv": "timestamp"])
        #expect(await database.value("albums/a/avgRating").raw as? Double == 8)
        #expect(await database.value("albums/a/ratingCount").raw as? Int == 1)
    }

    // Writing the two nodes separately could half-succeed and orphan an aggregate entry.
    @Test func `both sides of a rating go out in one update`() async throws {
        let database = FakeRealtimeDatabase()

        _ = try await makeDatabaseService(database).saveUserRating(userId: "u", albumId: "a", rating: 8, albumMetadata: nil)

        #expect(await database.updates.first?.keys == ["users/u/user_ratings/a", "album_ratings/a/u"])
    }

    @Test func `existing album keeps its details when rated again`() async throws {
        let database = FakeRealtimeDatabase(DatabaseValue([
            "albums": ["a": ["title": "Original"]],
            "album_ratings": ["a": ["other": 4.0]],
        ]))

        let stats = try await makeDatabaseService(database).saveUserRating(userId: "u", albumId: "a", rating: 8, albumMetadata: (artist: "X", title: "Renamed"))

        #expect(stats == (avgRating: 6, ratingCount: 2))
        #expect(await database.value("albums/a/title").raw as? String == "Original")
    }

    @Test func `album is not created without metadata`() async throws {
        let database = FakeRealtimeDatabase()

        _ = try await makeDatabaseService(database).saveUserRating(userId: "u", albumId: "a", rating: 8, albumMetadata: nil)

        #expect(await database.value("albums/a/title").raw == nil)
    }

    // An all-or-nothing cast would let one bad child wipe every other user's rating.
    @Test func `average ignores unrated and malformed entries`() async throws {
        let database = FakeRealtimeDatabase(DatabaseValue(["album_ratings": ["a": ["zero": 0.0, "bad": "x", "other": 6.0]]]))

        let stats = try await makeDatabaseService(database).saveUserRating(userId: "u", albumId: "a", rating: 10, albumMetadata: nil)

        #expect(stats == (avgRating: 8, ratingCount: 2))
    }

    @Test func `removing a rating clears both sides and recomputes the album`() async throws {
        let database = FakeRealtimeDatabase(DatabaseValue([
            "users": ["u": ["user_ratings": ["a": ["rating": 8.0, "timestamp": 1.0]]]],
            "album_ratings": ["a": ["u": 8.0, "other": 4.0]],
        ]))

        let stats = try await makeDatabaseService(database).removeUserRating(userId: "u", albumId: "a")

        #expect(stats == (avgRating: 4, ratingCount: 1))
        #expect(await database.value("users/u/user_ratings/a").raw == nil)
        #expect(await database.value("album_ratings/a/u").raw == nil)
    }

    @Test func `removing the last rating zeroes the album`() async throws {
        let database = FakeRealtimeDatabase(DatabaseValue(["album_ratings": ["a": ["u": 8.0]]]))

        let stats = try await makeDatabaseService(database).removeUserRating(userId: "u", albumId: "a")

        #expect(stats == (avgRating: 0, ratingCount: 0))
        #expect(await database.value("albums/a/ratingCount").raw as? Int == 0)
    }

    @Test func `failed stats write fails the rating`() async {
        let database = FakeRealtimeDatabase(failingWrites: ["albums/a/ratingCount"])

        await #expect(throws: StubError.self) {
            try await makeDatabaseService(database).saveUserRating(userId: "u", albumId: "a", rating: 8, albumMetadata: nil)
        }
    }
}
