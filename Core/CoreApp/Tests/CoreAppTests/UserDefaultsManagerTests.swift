import Foundation
import Testing
@testable import CoreApp

struct UserDefaultsManagerTests {
    @Test func `unknown stored player reads as nil`() {
        let storage = UserDefaults.isolated()
        storage.set("tidal", forKey: "mainMusicPlayer.u1")

        #expect(UserDefaultsManager(defaults: storage).mainMusicPlayer(for: "u1") == nil)
    }
}
