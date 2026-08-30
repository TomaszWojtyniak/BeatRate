//
//  SpotifyClient.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation
import Analytics
import OSLog

/// Performs authenticated Spotify requests and owns the retry policy. Holds no
/// mutable state; the token lifecycle belongs to `SpotifySession`.
nonisolated struct SpotifyClient: Sendable {

    /// Attempts *after* the first try, for retryable statuses only.
    static let maxRetries = 2
    /// Base for exponential backoff when the response carries no Retry-After.
    static let baseBackoff: TimeInterval = 0.5

    private let transport: any SpotifyTransport
    private let decoder = SpotifyNetworkClient()
    /// Injected so tests don't actually sleep.
    private let retryDelay: @Sendable (TimeInterval) async -> Void

    init(
        transport: any SpotifyTransport = URLSessionTransport(),
        retryDelay: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(for: .seconds(seconds))
        }
    ) {
        self.transport = transport
        self.retryDelay = retryDelay
    }

    func get<T: Decodable>(_ url: URL, session: SpotifySession) async throws -> T {
        let data = try await data(from: url, session: session)
        do {
            return try decoder.decode(data)
        } catch {
            Logger.spotifyService.error("Spotify response failed to decode: \(error)")
            throw SpotifyFailure.transient
        }
    }

    func data(from url: URL, session: SpotifySession) async throws -> Data {
        var accessToken = try await session.validAccessToken()
        var hasRefreshed = false
        var attempt = 0

        while true {
            let outcome = try await attemptRequest(url, accessToken: accessToken)

            switch outcome {
            case .success(let data):
                return data

            case .unauthorized:
                // One forced refresh — the stored token looked fresh but Spotify
                // disagrees (revoked access, rotated secret, clock skew).
                guard !hasRefreshed else {
                    Logger.spotifyService.error("Spotify still unauthorized after refresh — session expired")
                    await session.signOut()
                    throw SpotifyFailure.sessionExpired
                }
                hasRefreshed = true
                accessToken = try await session.refreshedAccessToken()

            case .retryable(let status, let retryAfter):
                guard attempt < Self.maxRetries else {
                    let failure = SpotifyResponseClassifier.failure(forStatus: status, retryAfter: retryAfter)
                        ?? SpotifyFailure.transient
                    Logger.spotifyService.error("Spotify request exhausted retries at \(status): \(url.path())")
                    throw failure
                }
                await retryDelay(retryAfter ?? Self.baseBackoff * pow(2, Double(attempt)))
                attempt += 1

            case .failed(let failure):
                throw failure
            }
        }
    }

    // MARK: - Single Attempt

    private enum Outcome {
        case success(Data)
        case unauthorized
        case retryable(status: Int, retryAfter: TimeInterval?)
        case failed(SpotifyFailure)
    }

    private func attemptRequest(_ url: URL, accessToken: String) async throws -> Outcome {
        var request = URLRequest(url: url)
        request.setValue(
            HTTP.HeaderValue.bearerPrefix + accessToken,
            forHTTPHeaderField: HTTP.Header.authorization
        )

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            // Offline or timed out. The session is fine — never sign out here.
            Logger.spotifyService.error("Spotify transport error for \(url.path()): \(error)")
            return .failed(SpotifyResponseClassifier.failure(forTransportError: error))
        }

        let status = response.statusCode
        if (200...299).contains(status) { return .success(data) }
        if status == HTTP.Status.unauthorized { return .unauthorized }
        if SpotifyResponseClassifier.isRetryable(status: status) {
            return .retryable(status: status, retryAfter: SpotifyResponseClassifier.retryAfterSeconds(from: response))
        }
        let failure = SpotifyResponseClassifier.failure(forStatus: status, retryAfter: nil) ?? .transient
        Logger.spotifyService.error("Spotify request failed with \(status): \(url.path())")
        return .failed(failure)
    }
}
