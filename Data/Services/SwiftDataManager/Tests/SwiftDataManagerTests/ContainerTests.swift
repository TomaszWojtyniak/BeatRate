import SwiftData
import Testing
@testable import SwiftDataManager

@MainActor
struct ContainerTests {

    @Test func `store that opens is used as is`() throws {
        let store = try Fixture.inMemoryContainer()
        var destroyed = false

        let container = SwiftDataManager.makeContainer(open: { _ in store }, destroyStore: { destroyed = true })

        #expect(container === store)
        #expect(!destroyed)
    }

    @Test func `unusable store is wiped and reopened`() throws {
        let rebuilt = try Fixture.inMemoryContainer()
        var attempts = 0
        var destroyed = 0

        let container = SwiftDataManager.makeContainer(
            open: { _ in
                attempts += 1
                if attempts == 1 { throw StubError() }
                return rebuilt
            },
            destroyStore: { destroyed += 1 }
        )

        #expect(container === rebuilt)
        #expect(destroyed == 1)
    }

    @Test func `store that cannot be rebuilt falls back to a working memory cache`() async throws {
        var destroyed = 0

        let container = SwiftDataManager.makeContainer(open: { _ in throw StubError() }, destroyStore: { destroyed += 1 })
        let manager = SwiftDataManager(container: container, appleUserIDStore: StubAppleUserIDStore())
        try await manager.setUserLoggedIn(userId: "uid")

        #expect(destroyed == 1)
        #expect(try await manager.getCurrentUserId() == "uid")
    }
}
