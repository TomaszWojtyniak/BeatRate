//
//  DatabaseFirebaseService.swift
//  FirebaseService
//
//  Created by Tomasz Wojtyniak on 29/07/2025.
//

import SwiftUI
import Analytics
import FirebaseDatabase
import OSLog
import Models

public protocol DatabaseFirebaseServiceProtocol: Sendable {
    func fetchSections() async throws -> [FirebaseAlbumSection]
    func fetchAlbumData(albumId: String) async throws -> FirebaseAlbumData?
}

public actor DatabaseFirebaseService: DatabaseFirebaseServiceProtocol {
    public static let shared = DatabaseFirebaseService()
    let analyticsManager: AnalyticsManager
    let crashLogger: CrashLogger
    
    private init(analyticsManager: AnalyticsManager = .shared,
                 crashLogger: CrashLogger = .shared) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
    }
    
    @MainActor
    public func fetchSections() async throws -> [FirebaseAlbumSection] {
        let ref = Database.database().reference().child("sections")
        let snapshot = try await ref.getData()

        guard let value = snapshot.value as? [String: Any] else {
            return []
        }

        let jsonData = try JSONSerialization.data(withJSONObject: value)
        let decoded = try JSONDecoder().decode([String: FirebaseAlbumSection].self, from: jsonData)

        return decoded.values.filter { $0.isActive }.sorted(by: { $0.id < $1.id })
    }

    @MainActor
    public func fetchAlbumData(albumId: String) async throws -> FirebaseAlbumData? {
        let ref = Database.database().reference().child("albums").child(albumId)
        let snapshot = try await ref.getData()

        guard snapshot.exists(), let value = snapshot.value as? [String: Any] else {
            Logger.firebaseService.info("No Firebase data found for album: \(albumId)")
            return nil
        }

        let jsonData = try JSONSerialization.data(withJSONObject: value)
        let decoded = try JSONDecoder().decode(FirebaseAlbumData.self, from: jsonData)

        Logger.firebaseService.info("Fetched Firebase data for album: \(albumId)")
        return decoded
    }
}

