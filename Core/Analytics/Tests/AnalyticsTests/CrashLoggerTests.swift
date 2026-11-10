import Foundation
import OSLog
import Testing
@testable import Analytics

@MainActor
struct CrashLoggerTests {
    private let backend = StubCrashBackend()
    private var logger: CrashLogger { CrashLogger(backend: backend) }

    @Test func `configure turns crash collection on`() {
        logger.configure()

        #expect(backend.calls.collectionEnabled == [true])
    }

    @Test func `user identifier is forwarded and can be cleared`() {
        let logger = logger

        logger.setUserIdentifier("u1")
        logger.setUserIdentifier(nil)

        #expect(backend.calls.userIDs == ["u1", nil])
    }

    @Test func `thrown error is recorded as a non fatal`() {
        logger.reportToCrashlytics(error: CocoaError(.fileNoSuchFile))

        #expect(backend.calls.errors.map(\.code) == [CocoaError.fileNoSuchFile.rawValue])
    }

    @Test(arguments: [
        ("HomeRepository/HomeRepository.swift", "[HomeRepository] cache miss"),
        ("Splash", "[Splash] cache miss"),
    ])
    func `breadcrumb is tagged with the module of the calling file`(file: String, breadcrumb: String) {
        logger.log("cache miss", to: Logger(subsystem: "BeatRateTests", category: "test"), level: .info, file: file)

        #expect(backend.calls.breadcrumbs == [breadcrumb])
    }

    @Test func `custom value is forwarded to crashlytics`() {
        logger.setValue("guest", forKey: "auth")

        #expect(backend.calls.customValues == ["auth": "guest"])
    }

    @Test func `report sends a non fatal named after its domain with the reason`() throws {
        logger.report("Recents", "empty list", to: nil)

        let error = try #require(backend.calls.errors.first)
        #expect(error.domain == "BeatRate.Recents")
        #expect(error.localizedDescription == "empty list")
        #expect(backend.calls.breadcrumbs == ["[Recents] empty list"])
    }

    @Test func `each domain is reported once per launch and later reasons stay breadcrumbs`() {
        let logger = logger

        logger.report("Recents", "first", to: nil)
        logger.report("Recents", "second", to: nil)
        logger.report("Auth", "denied", to: nil)

        #expect(backend.calls.errors.map(\.domain) == ["BeatRate.Recents", "BeatRate.Auth"])
        #expect(backend.calls.breadcrumbs == ["[Recents] first", "[Recents] second", "[Auth] denied"])
    }
}
