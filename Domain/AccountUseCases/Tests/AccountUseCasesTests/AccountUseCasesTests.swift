import Models
import SwiftDataManager
import Testing
@testable import AccountUseCases

@MainActor
struct AccountUseCasesTests {
    private let account = StubAccountRepository()
    private let cache = SwiftDataManager.inMemory()

    private var useCase: GetAccountUseCase { GetAccountUseCase(accountRepository: account, swiftDataManager: cache) }

    private static func album(_ id: String) -> AlbumModel {
        AlbumModel(id: id, appleMusicAlbumData: AppleMusicAlbumData(id: id, title: id, artist: "A", coverUrl: nil, releaseDate: nil, genre: nil), firebaseAlbumData: nil)
    }

    @Test func `current user id comes from local storage`() async throws {
        #expect(try await useCase.getCurrentUserId() == nil)

        try await cache.setUserLoggedIn(userId: "u")

        #expect(try await useCase.getCurrentUserId() == "u")
    }

    @Test func `album lists come from the account repository`() async throws {
        account.rated = [Self.album("r")]
        account.recentlyListened = [Self.album("l")]
        account.favorites = [Self.album("f")]
        let useCase = useCase

        #expect(try await useCase.getUserRatedAlbums().map(\.id) == ["r"])
        #expect(try await useCase.getRecentlyListenedAlbums(for: .spotify).map(\.id) == ["l"])
        #expect(try await useCase.getFavoriteAlbums().map(\.id) == ["f"])
        let sections = try await useCase.getAlbumSections(recentlyListenedFor: nil)
        #expect(sections.rated?.map(\.id) == ["r"])
        #expect(sections.recentlyListened?.map(\.id) == ["l"])
        #expect(account.requestedPlayers == [.spotify, nil])
    }

    @Test func `favorites are saved through the account repository`() async throws {
        try await SetAccountUseCase(accountRepository: account).setFavoriteAlbums(albumIds: ["b", "a"])

        #expect(account.savedFavorites == [["b", "a"]])
    }
}
