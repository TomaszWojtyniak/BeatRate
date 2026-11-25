//
//  Edges.swift
//  Composition
//

import AuthenticationServices
import Foundation
import SwiftData
import Analytics
import CoreApp
import FirebaseService
import MusicKitService
import SpotifyService

/// Everything the graph reaches outside the process — the SDKs, the system
/// stores and the analytics sinks. The app passes `Edges.live()`; tests pass stubs.
public struct Edges {
    public var database: any RealtimeDatabase
    public var firebaseAuth: any FirebaseAuthProviding
    public var musicKit: any MusicKitServiceProtocol
    public var spotifyTransport: any SpotifyTransport
    public var spotifyPresenter: @Sendable () async -> (any SpotifyAuthorizationPresenter)?
    public var keychain: any KeychainBackend
    public var appleIDCredentialState: @Sendable (String) async -> ASAuthorizationAppleIDProvider.CredentialState
    public var defaults: UserDefaults
    public var modelContainer: ModelContainer
    public var analytics: any AnalyticsBackend
    public var crash: any CrashBackend
    /// The pause between the splash's fetch attempts; the CLI sets it from a fixture.
    public var retryDelay: Duration

    public init(
        database: any RealtimeDatabase,
        firebaseAuth: any FirebaseAuthProviding,
        musicKit: any MusicKitServiceProtocol,
        spotifyTransport: any SpotifyTransport,
        spotifyPresenter: @escaping @Sendable () async -> (any SpotifyAuthorizationPresenter)?,
        keychain: any KeychainBackend,
        appleIDCredentialState: @escaping @Sendable (String) async -> ASAuthorizationAppleIDProvider.CredentialState,
        defaults: UserDefaults,
        modelContainer: ModelContainer,
        analytics: any AnalyticsBackend,
        crash: any CrashBackend,
        retryDelay: Duration = .seconds(2)
    ) {
        self.database = database
        self.firebaseAuth = firebaseAuth
        self.musicKit = musicKit
        self.spotifyTransport = spotifyTransport
        self.spotifyPresenter = spotifyPresenter
        self.keychain = keychain
        self.appleIDCredentialState = appleIDCredentialState
        self.defaults = defaults
        self.modelContainer = modelContainer
        self.analytics = analytics
        self.crash = crash
        self.retryDelay = retryDelay
    }
}
