//
//  SpotifyResponseClassifier.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation

/// Pure mapping from an HTTP outcome to a `SpotifyFailure`. No I/O, no state —
/// so the whole retry policy can be tested without a network.
///
/// Note on 401: this maps it to `.sessionExpired`, which is only correct as a
/// *final* outcome. `SpotifyClient` refreshes and retries once before asking
/// the classifier to judge a 401.
nonisolated enum SpotifyResponseClassifier {

    static func failure(forStatus status: Int, retryAfter: TimeInterval?) -> SpotifyFailure? {
        switch status {
        case 200...299: nil
        case 401: .sessionExpired
        case 403: .notAllowlisted
        case 429: .rateLimited(retryAfter: retryAfter)
        default: .transient
        }
    }

    /// 429 and 5xx are worth another attempt. 401/403 are verdicts, not weather.
    static func isRetryable(status: Int) -> Bool {
        status == 429 || (500...599).contains(status)
    }

    static func failure(forTransportError error: Error) -> SpotifyFailure {
        guard let urlError = error as? URLError else { return .transient }
        return urlError.code == .cancelled ? .authCancelled : .transient
    }

    static func retryAfterSeconds(from response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: HTTP.Header.retryAfter) else { return nil }
        return TimeInterval(raw)
    }
}
