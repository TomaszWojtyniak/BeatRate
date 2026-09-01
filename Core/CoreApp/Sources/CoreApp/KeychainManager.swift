//
//  KeychainManager.swift
//  CoreApp
//
//  Created by Tomasz Wojtyniak on 11/11/2025.
//

import Foundation
import Security

public enum KeychainError: Error {
    case saveFailed
    case loadFailed
    case deleteFailed
    case unexpectedData
}

public actor KeychainManager {
    public static let shared = KeychainManager()

    private init() {}

    private let service = "com.beatrate.app"

    private enum Key {
        static let appleUserID = "appleUserID"
        /// The whole Spotify token set as one JSON item.
        static let spotifyTokens = "spotifyTokens"
        /// Pre-refactor keys, read once for migration then removed.
        static let legacySpotifyAccessToken = "spotifyAccessToken"
        static let legacySpotifyRefreshToken = "spotifyRefreshToken"
    }

    // MARK: - Generic Access

    /// `SecItemUpdate` first so an existing item keeps its creation metadata;
    /// delete-then-add leaves a window where the item simply doesn't exist.
    private func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let insert = query.merging(attributes) { current, _ in current }
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else {
                throw KeychainError.saveFailed
            }
            return
        }
        guard status == errSecSuccess else { throw KeychainError.saveFailed }
    }

    private func load(_ key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { return nil }
            throw KeychainError.loadFailed
        }
        guard let data = result as? Data else { throw KeychainError.unexpectedData }
        return data
    }

    private func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed
        }
    }

    private func saveString(_ value: String, for key: String) throws {
        try save(Data(value.utf8), for: key)
    }

    private func loadString(_ key: String) throws -> String? {
        guard let data = try load(key) else { return nil }
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return value
    }

    // MARK: - Apple User ID

    public func saveAppleUserID(_ userID: String) throws {
        try saveString(userID, for: Key.appleUserID)
    }

    public func loadAppleUserID() throws -> String? {
        try loadString(Key.appleUserID)
    }

    public func deleteAppleUserID() throws {
        try delete(Key.appleUserID)
    }

    // MARK: - Spotify Tokens

    public func saveSpotifyTokens(_ data: Data) throws {
        try save(data, for: Key.spotifyTokens)
    }

    public func loadSpotifyTokens() throws -> Data? {
        try load(Key.spotifyTokens)
    }

    public func deleteSpotifyTokens() throws {
        try delete(Key.spotifyTokens)
        try delete(Key.legacySpotifyAccessToken)
        try delete(Key.legacySpotifyRefreshToken)
    }

    /// Reads the pre-refactor token pair so existing users aren't signed out by
    /// the move to a single JSON item. Returns nil once migration has happened.
    public func loadLegacySpotifyTokenPair() throws -> (accessToken: String, refreshToken: String?)? {
        guard let accessToken = try loadString(Key.legacySpotifyAccessToken) else { return nil }
        return (accessToken, try loadString(Key.legacySpotifyRefreshToken))
    }

    public func deleteLegacySpotifyTokens() throws {
        try delete(Key.legacySpotifyAccessToken)
        try delete(Key.legacySpotifyRefreshToken)
    }
}
