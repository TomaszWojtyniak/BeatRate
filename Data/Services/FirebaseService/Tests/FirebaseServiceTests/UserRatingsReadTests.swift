import Foundation
import Testing
@testable import FirebaseService

@MainActor
struct UserRatingsReadTests {

    /// New `{rating, timestamp}` entries, one without a timestamp, a legacy bare
    /// number and one unreadable entry.
    private static let database = FakeRealtimeDatabase(DatabaseValue(["users": ["u": ["user_ratings": [
        "old": ["rating": 6.0, "timestamp": 100.0],
        "new": ["rating": 9.0, "timestamp": 300.0],
        "legacy": 4.0,
        "undated": ["rating": 5.0],
        "broken": "ten",
    ]]]]))

    private var service: DatabaseFirebaseService { makeDatabaseService(Self.database) }

    @Test func `single rating is read from the new format only`() async throws {
        #expect(try await service.getUserRating(userId: "u", albumId: "new") == 9)
        #expect(try await service.getUserRating(userId: "u", albumId: "legacy") == nil)
    }

    @Test func `rated albums are newest first with undated ones last`() async throws {
        let ids = try await service.getUserRatedAlbumIds(userId: "u")

        #expect(Array(ids.prefix(2)) == ["new", "old"])
        #expect(Set(ids.dropFirst(2)) == ["legacy"])
    }

    @Test func `all ratings read both formats and skip unreadable ones`() async throws {
        let ratings = try await service.getAllUserRatings(userId: "u")

        #expect(ratings == ["old": 6, "new": 9, "legacy": 4, "undated": 5])
    }

    @Test func `sorted ratings carry values newest first`() async throws {
        let ratings = try await service.getUserRatingsSorted(userId: "u")

        #expect(ratings.prefix(2).map(\.albumId) == ["new", "old"])
        #expect(ratings.prefix(2).map(\.rating) == [9, 6])
        #expect(Set(ratings.dropFirst(2).map(\.albumId)) == ["legacy", "undated"])
    }

    @Test func `user without ratings has none`() async throws {
        let service = makeDatabaseService(FakeRealtimeDatabase())

        #expect(try await service.getUserRating(userId: "u", albumId: "a") == nil)
        #expect(try await service.getUserRatedAlbumIds(userId: "u").isEmpty)
        #expect(try await service.getAllUserRatings(userId: "u").isEmpty)
        #expect(try await service.getUserRatingsSorted(userId: "u").isEmpty)
    }
}
