//
//  SpotifyTransport.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation

/// The seam that makes the retry policy testable. Production uses URLSession;
/// tests supply a stub that returns scripted responses.
nonisolated protocol SpotifyTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

nonisolated struct URLSessionTransport: SpotifyTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyFailure.transient
        }
        return (data, httpResponse)
    }
}
