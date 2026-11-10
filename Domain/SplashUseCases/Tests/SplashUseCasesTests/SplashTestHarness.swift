import AuthenticationServices
import CoreApp
import Foundation
import Models
@testable import SplashUseCases

/// Every collaborator of `GetSplashUseCase`, each one fresh per test.
@MainActor
struct SplashTestHarness {
    let music = StubMusicRepository()
    let home = StubHomeRepository()
    let login = StubLoginRepository()
    let cache = StubSwiftDataManager()
    let loginUseCases = StubLoginUseCases()
    let session = SessionManager()
    let defaults = UserDefaultsManager(defaults: UserDefaults(suiteName: "SplashUseCasesTests.\(UUID())")!)
    let player: MusicPlayerManager
    let keychain: StubAppleCredentialStore
    let useCase: GetSplashUseCase

    init(keychain: StubAppleCredentialStore = StubAppleCredentialStore(),
         credentialState: ASAuthorizationAppleIDProvider.CredentialState = .authorized) {
        self.keychain = keychain
        player = MusicPlayerManager(userDefaultsManager: defaults)
        useCase = GetSplashUseCase(
            musicRepository: music,
            homeRepository: home,
            loginRepository: login,
            swiftDataManager: cache,
            getLoginUseCase: loginUseCases,
            sessionManager: session,
            musicPlayerManager: player,
            userDefaultsManager: defaults,
            credentialStore: keychain,
            credentialState: { _ in credentialState }
        )
    }

    func signIn(_ userId: String = "u") {
        cache.userId = userId
        cache.loggedIn = true
    }
}
