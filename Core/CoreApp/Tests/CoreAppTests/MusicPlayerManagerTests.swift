import Foundation
import Models
import Testing
@testable import CoreApp

@MainActor
struct MusicPlayerManagerTests {
    private let defaults = UserDefaultsManager(defaults: .isolated())
    private var manager: MusicPlayerManager { MusicPlayerManager(userDefaultsManager: defaults) }

    @Test func `nothing is selected before hydrating`() {
        #expect(manager.current == nil)
    }

    @Test func `set selects the player and persists it for that user`() {
        let manager = manager

        manager.set(.spotify, for: "u1")

        #expect(manager.current == .spotify)
        #expect(defaults.mainMusicPlayer(for: "u1") == .spotify)
    }

    @Test func `hydrate restores the saved choice of that user only`() {
        defaults.setMainMusicPlayer(.appleMusic, for: "u1")
        let manager = manager

        manager.hydrate(for: "u1")
        #expect(manager.current == .appleMusic)

        manager.hydrate(for: "u2")
        #expect(manager.current == nil)
    }

    @Test func `clear forgets the choice in memory and on disk`() {
        let manager = manager
        manager.set(.spotify, for: "u1")

        manager.clear(for: "u1")

        #expect(manager.current == nil)
        #expect(defaults.mainMusicPlayer(for: "u1") == nil)
    }
}
