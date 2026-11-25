//
//  Edges+Live.swift
//  CompositionLive
//

#if os(iOS)
import AnalyticsFirebase
import Composition
import CoreApp
import FirebaseServiceLive
import MusicKitServiceLive
import SplashUseCases
import SpotifyService
import SpotifyServiceLive
import SwiftDataManager

public extension Edges {
    /// The real SDKs and system stores the app runs on.
    static func live() -> Edges {
        Edges(
            database: FirebaseRealtimeDatabase(url: AppEnvironment.current.firebaseDatabaseUrl),
            firebaseAuth: FirebaseAuthProvider(),
            musicKit: MusicKitService(),
            spotifyTransport: URLSessionTransport(),
            spotifyPresenter: { @MainActor in SpotifyWebAuthSession.make() },
            keychain: SecItemKeychainBackend(),
            appleIDCredentialState: GetSplashUseCase.fetchAppleIDCredentialState,
            defaults: .standard,
            modelContainer: SwiftDataManager.makeContainer(),
            analytics: FirebaseAnalyticsBackend(),
            crash: FirebaseCrashBackend()
        )
    }
}
#endif
