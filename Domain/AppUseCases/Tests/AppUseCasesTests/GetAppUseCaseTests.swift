import Models
import SwiftDataManager
import Testing
@testable import AppUseCases

@MainActor
struct GetAppUseCaseTests {
    private let cache = SwiftDataManager.inMemory()

    private var useCase: GetAppUseCase { GetAppUseCase(swiftDataManager: cache) }

    @Test func `guest has no current user`() async throws {
        #expect(try await useCase.getCurrentUser() == nil)
        #expect(await !useCase.isUserLoggedIn())
    }

    @Test func `signed in user is reported and announced`() async throws {
        let useCase = useCase
        var states = useCase.observeLoginState().makeAsyncIterator()

        try await cache.setUserLoggedIn(userId: "u")

        #expect(try await useCase.getCurrentUser()?.userId == "u")
        #expect(await useCase.isUserLoggedIn())
        #expect(await states.next() == true)
    }
}
