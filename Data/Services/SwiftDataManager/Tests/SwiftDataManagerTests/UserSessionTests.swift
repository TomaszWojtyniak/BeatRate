import Foundation
import Models
import Testing
@testable import SwiftDataManager

@MainActor
struct UserSessionTests {

    @Test func `fresh install has no signed in user`() async throws {
        let manager = try ManagerUnderTest().manager

        #expect(try await manager.getCurrentUser() == nil)
        #expect(await !manager.isUserLoggedIn())
        #expect(try await manager.getCurrentUserId() == nil)
    }

    @Test func `signing in stores the user and announces it`() async throws {
        let manager = try ManagerUnderTest().manager
        var states = manager.observeLoginState().makeAsyncIterator()

        try await manager.setUserLoggedIn(userId: "uid")

        #expect(await manager.isUserLoggedIn())
        #expect(try await manager.getCurrentUserId() == "uid")
        #expect(await states.next() == true)
    }

    @Test func `signing in again reuses the single user row`() async throws {
        let sut = try ManagerUnderTest()

        try await sut.manager.setUserLoggedIn(userId: "first")
        try await sut.manager.setUserLoggedIn(userId: "second")

        #expect(try sut.count(User.self) == 1)
        #expect(try await sut.manager.getCurrentUserId() == "second")
    }

    @Test func `duplicate user rows are collapsed on sign in`() async throws {
        let sut = try ManagerUnderTest()
        sut.manager.context.insert(User())
        sut.manager.context.insert(User())

        try await sut.manager.setUserLoggedIn(userId: "uid")

        #expect(try sut.count(User.self) == 1)
    }

    @Test func `duplicate user rows are collapsed when reading the user`() async throws {
        let sut = try ManagerUnderTest()
        sut.manager.context.insert(User(isLoggedIn: true, userId: "uid"))
        sut.manager.context.insert(User(isLoggedIn: true, userId: "uid"))

        _ = try await sut.manager.getCurrentUser()

        #expect(try sut.count(User.self) == 1)
    }

    @Test func `signing out forgets the user, the apple id and every cache`() async throws {
        let sut = try ManagerUnderTest()
        let manager = sut.manager
        try await manager.setUserLoggedIn(userId: "uid")
        try await manager.cacheSections([HomeSection(name: "New", albums: [Fixture.album("a")])])
        try await manager.saveRecentAlbum(Fixture.appleMusicAlbum("r"))
        var states = manager.observeLoginState().makeAsyncIterator()
        _ = await states.next()

        try await manager.setUserLoggedOut()

        #expect(await !manager.isUserLoggedIn())
        #expect(try await manager.getCurrentUserId() == nil)
        #expect(await sut.keychain.deleteCount == 1)
        #expect(try sut.count(CachedSection.self) == 0)
        #expect(try sut.count(CachedAlbum.self) == 0)
        #expect(try sut.count(RecentAlbum.self) == 0)
        #expect(await states.next() == false)
    }

    @Test func `keychain failure does not stop sign out`() async throws {
        let sut = try ManagerUnderTest(keychain: StubAppleUserIDStore(failsToDelete: true))
        try await sut.manager.setUserLoggedIn(userId: "uid")

        try await sut.manager.setUserLoggedOut()

        #expect(await !sut.manager.isUserLoggedIn())
        #expect(await sut.keychain.deleteCount == 1)
    }

    @Test func `signing out a guest still clears the apple id`() async throws {
        let sut = try ManagerUnderTest()

        try await sut.manager.setUserLoggedOut()

        #expect(await sut.keychain.deleteCount == 1)
        #expect(try sut.count(User.self) == 0)
    }
}
