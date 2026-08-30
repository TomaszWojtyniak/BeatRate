import Foundation
import Testing
@testable import SpotifyService

struct SpotifyResponseClassifierTests {

    @Test func successStatusesProduceNoFailure() {
        #expect(SpotifyResponseClassifier.failure(forStatus: 200, retryAfter: nil) == nil)
        #expect(SpotifyResponseClassifier.failure(forStatus: 204, retryAfter: nil) == nil)
    }

    @Test func unauthorizedMapsToSessionExpired() {
        #expect(SpotifyResponseClassifier.failure(forStatus: 401, retryAfter: nil) == .sessionExpired)
    }

    @Test func forbiddenMapsToNotAllowlisted() {
        #expect(SpotifyResponseClassifier.failure(forStatus: 403, retryAfter: nil) == .notAllowlisted)
    }

    @Test func tooManyRequestsCarriesRetryAfter() {
        #expect(SpotifyResponseClassifier.failure(forStatus: 429, retryAfter: 12) == .rateLimited(retryAfter: 12))
    }

    @Test func serverErrorsMapToTransient() {
        #expect(SpotifyResponseClassifier.failure(forStatus: 500, retryAfter: nil) == .transient)
        #expect(SpotifyResponseClassifier.failure(forStatus: 503, retryAfter: nil) == .transient)
    }

    @Test func retryableCoversRateLimitAndServerErrors() {
        #expect(SpotifyResponseClassifier.isRetryable(status: 429))
        #expect(SpotifyResponseClassifier.isRetryable(status: 502))
        #expect(SpotifyResponseClassifier.isRetryable(status: 503))
        #expect(!SpotifyResponseClassifier.isRetryable(status: 403))
        #expect(!SpotifyResponseClassifier.isRetryable(status: 401))
    }

    @Test func offlineTransportErrorIsTransientNotSessionLoss() {
        let offline = URLError(.notConnectedToInternet)
        #expect(SpotifyResponseClassifier.failure(forTransportError: offline) == .transient)
    }

    @Test func cancelledTransportErrorIsAuthCancelled() {
        #expect(SpotifyResponseClassifier.failure(forTransportError: URLError(.cancelled)) == .authCancelled)
    }

    @Test func retryAfterHeaderIsParsedAsSeconds() throws {
        let response = try #require(HTTPURLResponse(
            url: URL(string: "https://api.spotify.com/v1/me")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "7"]
        ))
        #expect(SpotifyResponseClassifier.retryAfterSeconds(from: response) == 7)
    }

    @Test func missingRetryAfterHeaderIsNil() throws {
        let response = try #require(HTTPURLResponse(
            url: URL(string: "https://api.spotify.com/v1/me")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: [:]
        ))
        #expect(SpotifyResponseClassifier.retryAfterSeconds(from: response) == nil)
    }
}
