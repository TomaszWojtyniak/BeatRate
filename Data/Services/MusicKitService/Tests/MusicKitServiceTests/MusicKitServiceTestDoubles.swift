import Foundation
@testable import MusicKitService

struct StubError: Error {}

/// Serves canned Apple Music API pages by URL and records what was asked for.
actor StubAppleMusicDataSource: AppleMusicDataSource {
    private let pages: [String: Data]
    private let storefront: String
    private let failsCountryCode: Bool
    private(set) var requestedURLs: [String] = []
    private(set) var countryCodeCount = 0

    init(pages: [URL: Data] = [:], storefront: String = "pl", failsCountryCode: Bool = false) {
        self.pages = Dictionary(uniqueKeysWithValues: pages.map { ($0.key.absoluteString, $0.value) })
        self.storefront = storefront
        self.failsCountryCode = failsCountryCode
    }

    func data(for request: URLRequest) async throws -> Data {
        guard let url = request.url else { throw StubError() }
        requestedURLs.append(url.absoluteString)
        guard let page = pages[url.absoluteString] else { throw StubError() }
        return page
    }

    func countryCode() async throws -> String {
        countryCodeCount += 1
        if failsCountryCode { throw StubError() }
        return storefront
    }
}

enum TracksFixture {
    static func page(_ tracks: [(id: String, name: String)], next: String? = nil) -> Data {
        let resources = tracks.map { #"{"id":"\#($0.id)","attributes":{"name":"\#($0.name)"}}"# }
        let nextField = next.map { #","next":"\#($0)""# } ?? ""
        return Data(#"{"data":[\#(resources.joined(separator: ","))]\#(nextField)}"#.utf8)
    }
}
