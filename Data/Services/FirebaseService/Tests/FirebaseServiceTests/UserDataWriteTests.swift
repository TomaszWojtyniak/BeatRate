import Foundation
import Models
import Testing
@testable import FirebaseService

@MainActor
struct UserDataWriteTests {

    // A writer that knows only some fields used to wipe the rest of the profile.
    @Test func `saving a profile merges fields and clears only removed names`() async throws {
        let database = FakeRealtimeDatabase(DatabaseValue(["users": ["u": [
            "profile": ["firstName": "Old", "lastName": "Name", "mainMusicPlayer": "spotify"],
            "user_ratings": ["a": 5.0],
        ]]]))

        try await makeDatabaseService(database).saveUserProfile(userId: "u", profile: FirebaseUserProfile(email: "a@b.c", firstName: "New", lastName: nil))

        #expect(await database.value("users/u/profile/firstName").raw as? String == "New")
        #expect(await database.value("users/u/profile/lastName").raw == nil)
        #expect(await database.value("users/u/profile/email").raw as? String == "a@b.c")
        #expect(await database.value("users/u/profile/mainMusicPlayer").raw as? String == "spotify")
        #expect(await database.updates.first?.keys.contains("user_ratings") == false)
    }

    @Test func `first profile save also prepares the ratings node`() async throws {
        let database = FakeRealtimeDatabase()

        try await makeDatabaseService(database).saveUserProfile(userId: "u", profile: FirebaseUserProfile(email: nil, firstName: "A", lastName: "B"))

        #expect(await database.updates.first?.path == "users/u")
        #expect(await database.updates.first?.keys.contains("user_ratings") == true)
    }

    @Test func `favorites keep their order and skip non string entries`() async throws {
        let database = FakeRealtimeDatabase(DatabaseValue(["users": ["u": ["favorites": ["b", 1, "a"]]]]))

        #expect(try await makeDatabaseService(database).getFavoriteAlbumIds(userId: "u") == ["b", "a"])
    }

    @Test func `saved favorites read back in order`() async throws {
        let service = makeDatabaseService(FakeRealtimeDatabase())

        try await service.saveFavoriteAlbumIds(userId: "u", albumIds: ["c", "a", "b"])

        #expect(try await service.getFavoriteAlbumIds(userId: "u") == ["c", "a", "b"])
    }

    @Test func `saving no favorites removes the node`() async throws {
        let database = FakeRealtimeDatabase(DatabaseValue(["users": ["u": ["favorites": ["a"]]]]))
        let service = makeDatabaseService(database)

        try await service.saveFavoriteAlbumIds(userId: "u", albumIds: [])

        #expect(await database.value("users/u/favorites").raw == nil)
        #expect(try await service.getFavoriteAlbumIds(userId: "u").isEmpty)
    }

    @Test func `deleting a user wipes their node and their share of every album`() async throws {
        let database = FakeRealtimeDatabase(DatabaseValue([
            "users": ["u": ["profile": ["email": "a@b.c"], "user_ratings": ["a": ["rating": 8.0, "timestamp": 1.0], "b": 2.0]]],
            "album_ratings": ["a": ["u": 8.0, "other": 6.0], "b": ["u": 2.0]],
        ]))

        try await makeDatabaseService(database).deleteUserData(userId: "u")

        #expect(await database.value("users/u").raw == nil)
        #expect(await database.value("album_ratings/a/u").raw == nil)
        #expect(await database.value("albums/a/avgRating").raw as? Double == 6)
        #expect(await database.value("albums/b/ratingCount").raw as? Int == 0)
    }

    // A stale average is a data-quality issue, not a reason to abort account deletion.
    @Test func `failed recompute does not stop account deletion`() async throws {
        let database = FakeRealtimeDatabase(
            DatabaseValue([
                "users": ["u": ["user_ratings": ["a": 8.0, "b": 2.0]]],
                "album_ratings": ["a": ["u": 8.0], "b": ["u": 2.0, "other": 4.0]],
            ]),
            failingReads: ["album_ratings/a"]
        )

        try await makeDatabaseService(database).deleteUserData(userId: "u")

        #expect(await database.value("users/u").raw == nil)
        #expect(await database.value("albums/b/avgRating").raw as? Double == 4)
    }
}
