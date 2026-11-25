import Foundation
import AccountRepository
import AccountUseCases
import Analytics
import AppUseCases
import ArtistUseCase
import CoreApp
import FirebaseService
import HomeRepository
import HomeUseCases
import LoginRepository
import LoginUseCases
import MusicKitService
import MusicRepository
import SearchRepository
import SearchUse
import SettingUseCases
import SplashUseCases
import SpotifyService
import SwiftDataManager

/// Builds the app's objects once: one instance of every service, repository and
/// use case per process, so every screen shares the same caches and session.
public final class Graph {
    /// ponytail: transitional. Read only by legacy DataModels, TabBarView and
    /// AppDelegate; phase 6 removes it once every screen gets its dependencies via init.
    public static var current: Graph!

    public let analytics: AnalyticsManager
    public let session: SessionManager
    public let players: MusicPlayerManager
    public let getApp: any GetAppUseCaseProtocol
    public let getHome: any GetHomeUseCaseProtocol
    public let setHome: any SetHomeUseCaseProtocol
    public let getAlbumById: any GetAlbumByIdUseCaseProtocol
    public let getAlbumDetails: any GetAlbumDetailsUseCaseProtocol
    public let getArtistDetails: any GetArtistDetailsUseCaseProtocol
    public let getSearch: any GetSearchUseCaseProtocol
    public let getRecentAlbums: any GetRecentAlbumsUseCaseProtocol
    public let saveRecentAlbum: any SaveRecentAlbumUseCaseProtocol
    public let clearRecentAlbums: any ClearRecentAlbumsUseCaseProtocol
    public let getLogin: any GetLoginUseCaseProtocol
    public let setLogin: any SetLoginUseCaseProtocol
    public let getAccount: any GetAccountUseCaseProtocol
    public let setAccount: any SetAccountUseCaseProtocol
    public let getSettings: any GetSettingsUseCaseProtocol
    public let setSettings: any SetSettingsUseCaseProtocol
    public let getSplash: any GetSplashUseCaseProtocol

    public init(edges: Edges) {
        CrashLogger.shared.use(edges.crash)
        let userDefaults = UserDefaultsManager(defaults: edges.defaults)
        let keychain = KeychainManager(backend: edges.keychain)
        let analytics = AnalyticsManager(defaults: edges.defaults, backend: edges.analytics)
        let session = SessionManager()
        let players = MusicPlayerManager(userDefaultsManager: userDefaults)
        let swiftData = SwiftDataManager(container: edges.modelContainer, appleUserIDStore: keychain)

        let database = DatabaseFirebaseService(crashLogger: .shared, database: edges.database)
        let auth = AuthFirebaseService(auth: edges.firebaseAuth, analyticsManager: analytics,
                                       databaseService: database, keychainManager: keychain)
        let musicKit = edges.musicKit
        let spotify = SpotifyService(keychainManager: keychain, transport: edges.spotifyTransport,
                                     makePresenter: edges.spotifyPresenter)

        let music = MusicRepository(musicKitService: musicKit, spotifyService: spotify)
        let home = HomeRepository(databaseFirebaseService: database, musicRepository: music, swiftDataManager: swiftData)
        let login = LoginRepository(authFirebaseService: auth, databaseFirebaseService: database)
        let search = SearchRepository(swiftDataManager: swiftData)
        let account = AccountRepository(homeRepository: home, musicRepository: music,
                                        databaseFirebaseService: database, swiftDataManager: swiftData)

        let getLogin = GetLoginUseCase(loginRepository: login)
        let setLogin = SetLoginUseCase(loginRepository: login, swiftDataManager: swiftData)

        self.analytics = analytics
        self.session = session
        self.players = players
        self.getApp = GetAppUseCase(swiftDataManager: swiftData)
        self.getHome = GetHomeUseCase(homeRepository: home)
        self.setHome = SetHomeUseCase(musicKitService: musicKit, swiftDataManager: swiftData)
        self.getAlbumById = GetAlbumByIdUseCase(homeRepository: home, musicRepository: music)
        self.getAlbumDetails = GetAlbumDetailsUseCase(homeRepository: home, musicRepository: music)
        self.getArtistDetails = GetArtistDetailsUseCase(musicRepository: music)
        self.getSearch = GetSearchUseCase(musicRepository: music)
        self.getRecentAlbums = GetRecentAlbumsUseCase(searchRepository: search)
        self.saveRecentAlbum = SaveRecentAlbumUseCase(searchRepository: search)
        self.clearRecentAlbums = ClearRecentAlbumsUseCase(searchRepository: search)
        self.getLogin = getLogin
        self.setLogin = setLogin
        self.getAccount = GetAccountUseCase(accountRepository: account, swiftDataManager: swiftData)
        self.setAccount = SetAccountUseCase(accountRepository: account)
        self.getSettings = GetSettingsUseCase(getLoginUseCase: getLogin, swiftDataManager: swiftData, musicRepository: music,
                                              musicPlayerManager: players, userDefaultsManager: userDefaults)
        self.setSettings = SetSettingsUseCase(musicRepository: music, getLoginUseCase: getLogin, setLoginUseCase: setLogin,
                                              swiftDataManager: swiftData, musicPlayerManager: players)
        self.getSplash = GetSplashUseCase(musicRepository: music, homeRepository: home, loginRepository: login,
                                          swiftDataManager: swiftData, getLoginUseCase: getLogin, sessionManager: session,
                                          musicPlayerManager: players, userDefaultsManager: userDefaults,
                                          credentialStore: keychain, credentialState: edges.appleIDCredentialState)
    }
}
