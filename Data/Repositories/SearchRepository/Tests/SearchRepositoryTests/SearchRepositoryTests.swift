import Models
import SwiftDataManager
import Testing
@testable import SearchRepository

@MainActor
struct SearchRepositoryTests {
    private let repository = SearchRepository(swiftDataManager: .inMemory())

    private static func album(_ id: String) -> AppleMusicAlbumData {
        AppleMusicAlbumData(id: id, title: "Album \(id)", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil)
    }

    @Test func `saved album shows up in recent searches`() async throws {
        try await repository.saveRecentAlbum(Self.album("a"))

        #expect(try await repository.getRecentAlbums().map(\.id) == ["a"])
    }

    @Test func `clearing recents empties the list`() async throws {
        try await repository.saveRecentAlbum(Self.album("a"))

        try await repository.clearRecentAlbums()

        #expect(try await repository.getRecentAlbums().isEmpty)
    }
}
