import Models
import SwiftDataManager
import Testing
@testable import HomeUseCases

@MainActor
struct HomeUseCasesTests {
    private let home = StubHomeRepository()
    private let music = StubMusicRepository()

    private static let appleMusic = AppleMusicAlbumData(id: "a", title: "Album", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil)
    private static let album = AlbumModel(id: "a", appleMusicAlbumData: appleMusic, firebaseAlbumData: nil)
    private static let community = FirebaseAlbumData(artist: "Artist", avgRating: 8, createdAt: 1, ratingCount: 3, title: "Album")

    @Test func `home sections come from the home repository`() async throws {
        home.sections = [HomeSection(name: "New", albums: [Self.album])]

        #expect(try await GetHomeUseCase(homeRepository: home).fetchHomeSections().map(\.name) == ["New"])
    }

    @Test func `clearing the cache empties cached sections`() async throws {
        let cache = SwiftDataManager.inMemory()
        try await cache.cacheSections([HomeSection(name: "New", albums: [Self.album])])

        try await SetHomeUseCase(musicKitService: StubMusicKitService(), swiftDataManager: cache).clearCache()

        #expect(try await cache.getCachedSections().isEmpty)
    }

    // MARK: - Album by id

    @Test func `cached album is used as is`() async throws {
        home.cachedAlbum = Self.album

        #expect(try await GetAlbumByIdUseCase(homeRepository: home, musicRepository: music).fetchAlbum(id: "a") == Self.album)
    }

    @Test func `uncached album is built from the catalog and community data`() async throws {
        music.album = .success(Self.appleMusic)
        home.firebaseAlbum = .success(Self.community)

        let album = try await GetAlbumByIdUseCase(homeRepository: home, musicRepository: music).fetchAlbum(id: "a")

        #expect(album.appleMusicAlbumData == Self.appleMusic)
        #expect(album.firebaseAlbumData?.ratingCount == 3)
    }

    // An album nobody has rated has no Firebase entry yet.
    @Test func `album without readable community data still opens`() async throws {
        music.album = .success(Self.appleMusic)
        home.firebaseAlbum = .failure(StubError())

        let album = try await GetAlbumByIdUseCase(homeRepository: home, musicRepository: music).fetchAlbum(id: "a")

        #expect(album.id == "a")
        #expect(album.firebaseAlbumData == nil)
    }

    @Test func `album the catalog cannot find is an error`() async {
        await #expect(throws: StubError.self) {
            try await GetAlbumByIdUseCase(homeRepository: home, musicRepository: music).fetchAlbum(id: "a")
        }
    }

    // MARK: - Album details

    @Test func `album details read and save through the home repository`() async throws {
        home.userRating = 7
        home.cachedAlbum = Self.album
        home.fetchedAlbum = .success(Self.album)
        let useCase = GetAlbumDetailsUseCase(homeRepository: home, musicRepository: music)

        #expect(try await useCase.getUserRating(albumId: "a") == 7)
        #expect(try await useCase.getUpdatedAlbum(albumId: "a") == Self.album)
        #expect(try await useCase.fetchFullAlbum(albumId: "a") == Self.album)
        try await useCase.saveAlbumRating(albumId: "a", rating: 9, albumMetadata: (artist: "Artist", title: "Album"))

        #expect(home.savedRatings.map(\.rating) == [9])
        #expect(home.savedRatings.first?.title == "Album")
    }
}
