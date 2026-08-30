//
//  SpotifyNetworkClient.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation

// MARK: - HTTP Constants

nonisolated enum HTTP {
    enum Method {
        static let post = "POST"
    }

    enum Header {
        static let authorization = "Authorization"
        static let contentType = "Content-Type"
        static let retryAfter = "Retry-After"
    }

    enum HeaderValue {
        static let bearerPrefix = "Bearer "
        static let formURLEncoded = "application/x-www-form-urlencoded"
    }

    enum Status {
        static let unauthorized = 401
    }
}

// MARK: - SpotifyNetworkClient

/// Shared encoding/decoding helpers for the Spotify Web API. Requests
/// themselves go through `SpotifyClient` (endpoints) and `SpotifySession`
/// (token endpoint), which own retry and token handling respectively.
nonisolated struct SpotifyNetworkClient: Sendable {

    /// Spotify responses use snake_case keys (`access_token`, `refresh_token`).
    func decode<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    /// Percent-encodes via URLComponents; `+` is valid in a URL query but means
    /// a space in form-urlencoded bodies, so it needs escaping on top.
    static func formEncode(_ fields: [(name: String, value: String)]) -> Data? {
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.name, value: $0.value) }
        return components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
            .data(using: .utf8)
    }
}
