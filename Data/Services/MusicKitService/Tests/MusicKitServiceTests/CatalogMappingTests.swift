import Foundation
import Models
import MusicKit
import Testing
@testable import MusicKitService

@MainActor
struct CatalogMappingTests {

    private var service: MusicKitService { MusicKitService(analyticsManager: .shared, dataSource: StubAppleMusicDataSource()) }

    private static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    private static let albumJSON = #"""
    {"id":"1440857781","type":"albums","attributes":{
      "name":"Blonde","artistName":"Frank Ocean","genreNames":["R&B/Soul","Music"],
      "releaseDate":"2016-08-20","recordLabel":"Boys Don't Cry","copyright":"℗ 2016 Boys Don't Cry",
      "url":"https://music.apple.com/pl/album/blonde/1440857781",
      "artwork":{"url":"https://is1.mzstatic.com/image/{w}x{h}bb.jpg","width":3000,"height":3000}
    }}
    """#

    @Test func `catalog album maps onto the app model with a sized cover`() async throws {
        let album = try Self.decode(Album.self, Self.albumJSON)
        let tracks = [Models.Track(id: "t", title: "Nikes", trackNumber: 1, discNumber: 1, duration: 314, isExplicit: true)]

        let data = await service.albumData(from: album, tracks: tracks)

        #expect(data.id == "1440857781")
        #expect(data.title == "Blonde")
        #expect(data.artist == "Frank Ocean")
        #expect(data.genre == "R&B/Soul")
        #expect(data.recordLabel == "Boys Don't Cry")
        #expect(data.copyright == "℗ 2016 Boys Don't Cry")
        #expect(data.appleMusicUrl?.absoluteString == "https://music.apple.com/pl/album/blonde/1440857781")
        #expect(data.coverUrl?.absoluteString == "https://is1.mzstatic.com/image/300x300bb.jpg")
        #expect(data.releaseDate != nil)
        #expect(data.tracks == tracks)
    }

    @Test func `catalog artist maps onto the app model with its sections`() async throws {
        let artist = try Self.decode(Artist.self, #"""
        {"id":"442122051","type":"artists","attributes":{
          "name":"Frank Ocean","genreNames":["R&B/Soul"],
          "url":"https://music.apple.com/pl/artist/frank-ocean/442122051",
          "artwork":{"url":"https://is1.mzstatic.com/image/{w}x{h}cc.jpg","width":2400,"height":2400}
        }}
        """#)
        let album = AppleMusicAlbumData.albumPlaceholder

        let data = await service.artistData(from: artist, albums: [album], singles: [], latestRelease: album)

        #expect(data.id == "442122051")
        #expect(data.name == "Frank Ocean")
        #expect(data.genres == ["R&B/Soul"])
        #expect(data.imageUrl?.absoluteString == "https://is1.mzstatic.com/image/300x300cc.jpg")
        #expect(data.appleMusicUrl?.absoluteString == "https://music.apple.com/pl/artist/frank-ocean/442122051")
        #expect(data.albums == [album])
        #expect(data.singles == [])
        #expect(data.latestRelease == album)
    }

    @Test func `artist without genres or artwork maps to empty values`() async throws {
        let artist = try Self.decode(Artist.self, #"{"id":"1","type":"artists","attributes":{"name":"Unknown"}}"#)

        let data = await service.artistData(from: artist)

        #expect(data.genres.isEmpty)
        #expect(data.imageUrl == nil)
        #expect(data.albums == nil)
    }

    @Test func `authorization result carries status and subscription`() {
        let result = MusicAuthorizationResult(status: .denied, hasSubscription: false)

        #expect(result.status == .denied)
        #expect(!result.hasSubscription)
    }
}
