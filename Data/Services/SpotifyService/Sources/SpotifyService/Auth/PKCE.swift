//
//  PKCE.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation
import CryptoKit
import Security

/// Verifier/challenge pair for the OAuth authorization-code flow (RFC 7636).
nonisolated struct PKCE {
    /// 32 random bytes encode to a 43-character verifier, the RFC 7636 minimum.
    static let verifierByteCount = 32

    let verifier: String
    let challenge: String

    init() {
        var bytes = [UInt8](repeating: 0, count: Self.verifierByteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        verifier = Self.base64URLEncode(Data(bytes))
        challenge = Self.challenge(for: verifier)
    }

    static func challenge(for verifier: String) -> String {
        base64URLEncode(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
