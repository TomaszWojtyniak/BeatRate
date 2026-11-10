import Foundation
import Testing
@testable import CoreApp

@MainActor
struct AppEnvironmentTests {

    @Test(arguments: [
        ("com.beatrate.app.development", AppEnvironment.development),
        ("com.beatrate.app", .production),
        (nil, .production),
    ] as [(String?, AppEnvironment)])
    func `environment is picked from the bundle identifier`(bundleID: String?, expected: AppEnvironment) {
        #expect(AppEnvironment.from(bundleID: bundleID) == expected)
    }

    @Test func `current environment reads the main bundle`() {
        #expect(AppEnvironment.current == .from(bundleID: Bundle.main.bundleIdentifier))
    }

    @Test(arguments: [AppEnvironment.development, .production])
    func `exactly one environment flag is set`(environment: AppEnvironment) {
        #expect(environment.isDevelopment != environment.isProduction)
        #expect(environment.isDevelopment == (environment == .development))
    }

    @Test func `development and production use separate databases`() {
        #expect(AppEnvironment.development.firebaseDatabaseUrl != AppEnvironment.production.firebaseDatabaseUrl)
        #expect(AppEnvironment.production.firebaseDatabaseUrl.contains("production"))
    }

    @Test(arguments: [AppEnvironment.development, .production])
    func `spotify callback uses the app url scheme`(environment: AppEnvironment) {
        #expect(environment.spotifyRedirectUri == "beatrate://spotify-callback")
        #expect(!environment.spotifyClientId.isEmpty)
    }
}
