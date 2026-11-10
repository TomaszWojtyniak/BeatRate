//
//  AppleMusicDataSource.swift
//  MusicKitService
//

import Foundation
import MusicKit

/// The two raw Apple Music API calls the service makes outside MusicKit's typed
/// layer, behind a seam so pagination and storefront caching can be tested.
nonisolated protocol AppleMusicDataSource: Sendable {
    func data(for request: URLRequest) async throws -> Data
    func countryCode() async throws -> String
}

nonisolated struct MusicKitDataSource: AppleMusicDataSource {
    func data(for request: URLRequest) async throws -> Data {
        try await MusicDataRequest(urlRequest: request).response().data
    }

    func countryCode() async throws -> String {
        try await MusicDataRequest.currentCountryCode
    }
}
