import Models
import Testing
@testable import CoreUI

@MainActor
struct HomeSectionViewTests {

    private static let albums = (1...15).map { index in
        AlbumModel(
            id: "\(index)",
            appleMusicAlbumData: AppleMusicAlbumData(id: "\(index)", title: "Album \(index)", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil),
            firebaseAlbumData: nil
        )
    }

    @Test func `row with a see all destination is capped at the threshold`() {
        let visible = HomeSectionView.visibleAlbums(Self.albums, canSeeAll: true)

        #expect(visible == Array(Self.albums.prefix(HomeSectionView.seeAllThreshold)))
    }

    @Test func `row without a see all destination shows every album`() {
        #expect(HomeSectionView.visibleAlbums(Self.albums, canSeeAll: false) == Self.albums)
    }
}
