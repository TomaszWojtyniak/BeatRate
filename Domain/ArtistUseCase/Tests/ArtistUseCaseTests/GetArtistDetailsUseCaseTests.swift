import Models
import Testing
@testable import ArtistUseCase

@MainActor
struct GetArtistDetailsUseCaseTests {
    private let music = StubMusicRepository()
    private static let artist = AppleMusicArtistData(id: "ar", name: "Artist", imageUrl: nil, genres: [])

    @Test func `artist is fetched by its id or by one of its albums`() async throws {
        music.artist = .success(Self.artist)
        let useCase = GetArtistDetailsUseCase(musicRepository: music)

        #expect(try await useCase.fetchArtist(byId: "ar") == Self.artist)
        #expect(try await useCase.fetchArtist(forAlbumId: "al") == Self.artist)
        #expect(music.artistLookups == ["id:ar", "album:al"])
    }

    @Test func `missing artist is passed on`() async {
        let useCase = GetArtistDetailsUseCase(musicRepository: music)

        await #expect(throws: StubError.self) { try await useCase.fetchArtist(byId: "ar") }
        await #expect(throws: StubError.self) { try await useCase.fetchArtist(forAlbumId: "al") }
    }
}
