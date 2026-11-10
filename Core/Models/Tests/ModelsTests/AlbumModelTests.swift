import Testing
@testable import Models

struct AlbumModelTests {

    static func model(id: String = "1", avgRating: Double? = 9.1, ratingCount: Int? = 12, userRating: Double? = nil) -> AlbumModel {
        AlbumModel(
            id: id,
            appleMusicAlbumData: ModelsFixture.album,
            firebaseAlbumData: FirebaseAlbumData(artist: nil, avgRating: avgRating, createdAt: nil, ratingCount: ratingCount, title: nil),
            userRating: userRating
        )
    }

    @Test func `albums with the same id and ratings are equal`() {
        #expect(Self.model() == Self.model())
    }

    // Equality drives SwiftUI diffing, so any rating change must redraw the row.
    @Test(arguments: [
        AlbumModelTests.model(id: "2"),
        AlbumModelTests.model(avgRating: 5),
        AlbumModelTests.model(ratingCount: 1),
        AlbumModelTests.model(userRating: 7),
    ])
    func `a different id or rating makes albums unequal`(other: AlbumModel) {
        #expect(Self.model() != other)
    }

    @Test func `hash depends only on the id`() {
        #expect(Self.model().hashValue == Self.model(avgRating: 5).hashValue)
    }

    @Test func `user rating is optional`() {
        #expect(AlbumModel(id: "1", appleMusicAlbumData: ModelsFixture.album, firebaseAlbumData: nil).userRating == nil)
    }

    @Test func `placeholders describe an unrated generic album`() {
        let placeholder = AlbumModel.albumPlaceholder

        #expect(placeholder.appleMusicAlbumData == .albumPlaceholder)
        #expect(placeholder.firebaseAlbumData == nil)
        #expect(placeholder.userRating == nil)
    }
}
