//
//  AppleMusicDataSource.swift
//  MusicKitService
//

import Foundation

/// The two raw Apple Music API calls the service makes outside MusicKit's typed
/// layer, behind a seam so pagination and storefront caching can be tested.
nonisolated public protocol AppleMusicDataSource: Sendable {
    func data(for request: URLRequest) async throws -> Data
    func countryCode() async throws -> String
}
