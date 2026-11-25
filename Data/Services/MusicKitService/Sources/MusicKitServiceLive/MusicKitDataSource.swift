//
//  MusicKitDataSource.swift
//  MusicKitServiceLive
//

#if os(iOS)
import Foundation
import MusicKit
import MusicKitService

/// `AppleMusicDataSource` on MusicKit's `MusicDataRequest`.
nonisolated struct MusicKitDataSource: AppleMusicDataSource {
    func data(for request: URLRequest) async throws -> Data {
        try await MusicDataRequest(urlRequest: request).response().data
    }

    func countryCode() async throws -> String {
        try await MusicDataRequest.currentCountryCode
    }
}
#endif
