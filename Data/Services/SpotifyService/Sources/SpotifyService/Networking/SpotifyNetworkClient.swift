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
    }

    enum HeaderValue {
        static let bearerPrefix = "Bearer "
        static let formURLEncoded = "application/x-www-form-urlencoded"
    }

    enum Status {
        static let ok = 200
        static let unauthorized = 401
    }
}

// MARK: - SpotifyNetworkClient

/// Stateless transport for the Spotify Web API: bearer-authenticated GETs,
/// form-encoded POSTs, and JSON decoding. Holds no mutable state, so it is a
/// plain Sendable struct rather than an actor.
nonisolated struct SpotifyNetworkClient: Sendable {

    /// Performs a bearer-authenticated GET and returns the payload with its HTTP status.
    func get(_ url: URL, accessToken: String) async throws -> (data: Data, statusCode: Int) {
        var request = URLRequest(url: url)
        request.setValue(
            HTTP.HeaderValue.bearerPrefix + accessToken,
            forHTTPHeaderField: HTTP.Header.authorization
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, try statusCode(of: response))
    }

    /// Sends a form-URL-encoded POST (token exchange / refresh) and decodes the
    /// response on success.
    func postForm<T: Decodable>(_ url: URL, fields: [(name: String, value: String)]) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = HTTP.Method.post
        request.setValue(HTTP.HeaderValue.formURLEncoded, forHTTPHeaderField: HTTP.Header.contentType)
        request.httpBody = Self.formEncode(fields)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = try statusCode(of: response)
        guard status == HTTP.Status.ok else {
            throw SpotifyError.requestFailed(statusCode: status)
        }
        return try decode(data)
    }

    /// Spotify responses use snake_case keys (`access_token`, `refresh_token`).
    func decode<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    private func statusCode(of response: URLResponse) throws -> Int {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }
        return httpResponse.statusCode
    }

    /// Percent-encodes via URLComponents; `+` is valid in a URL query but means
    /// a space in form-urlencoded bodies, so it needs escaping on top.
    private static func formEncode(_ fields: [(name: String, value: String)]) -> Data? {
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.name, value: $0.value) }
        return components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
            .data(using: .utf8)
    }
}
