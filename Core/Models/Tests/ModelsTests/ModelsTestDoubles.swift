import Foundation
import SwiftData
@testable import Models

enum ModelsFixture {
    static let album = AppleMusicAlbumData(
        id: "1440857781",
        title: "Blonde",
        artist: "Frank Ocean",
        coverUrl: nil,
        releaseDate: nil,
        genre: nil
    )

    /// JSONEncoder refuses NaN, so this album can never be encoded.
    static let unencodableAlbum = AppleMusicAlbumData(
        id: "nan",
        title: "Broken",
        artist: "Nobody",
        coverUrl: nil,
        releaseDate: nil,
        genre: nil,
        tracks: [Track(id: "t", title: "Track", trackNumber: 1, discNumber: 1, duration: .nan, isExplicit: false)]
    )

    static let firebaseAlbum = FirebaseAlbumData(artist: "Frank Ocean", avgRating: 9.1, createdAt: 1, ratingCount: 12, title: "Blonde")

    static let unencodableFirebaseAlbum = FirebaseAlbumData(artist: nil, avgRating: .nan, createdAt: nil, ratingCount: nil, title: nil)

    static let undecodableBlob = Data("not json".utf8)

    static func album(id: String) -> AppleMusicAlbumData {
        AppleMusicAlbumData(id: id, title: "Album \(id)", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil)
    }

    /// A fresh in-memory store per test, so suites stay parallel-safe. Callers keep
    /// the container alive: a context whose container was freed traps on insert.
    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CachedSection.self, CachedAlbum.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
