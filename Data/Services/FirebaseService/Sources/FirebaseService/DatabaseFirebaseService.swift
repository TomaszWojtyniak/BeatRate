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
    func saveAlbumData(albumId: String, albumData: FirebaseAlbumData) async throws
    func getUserRating(userId: String, albumId: String) async throws -> Double?
    func getUserRatedAlbumIds(userId: String) async throws -> [String]
    func saveUserRating(userId: String, albumId: String, rating: Double, albumMetadata: (artist: String, title: String)?) async throws -> (avgRating: Double, ratingCount: Int)
    func getUserProfile(userId: String) async throws -> FirebaseUserProfile?
    func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws
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
    
    public func fetchSections() async throws -> [FirebaseAlbumSection] {
        let ref = Database.database().reference().child("sections")

        Logger.firebaseService.info("Fetching sections from Firebase...")
        let snapshot = try await ref.getData()

        Logger.firebaseService.debug("Snapshot exists: \(snapshot.exists())")

        guard let value = snapshot.value as? [String: Any] else {
            Logger.firebaseService.warning("No sections data found in Firebase or data format invalid")
            return []
        }

        Logger.firebaseService.debug("Found \(value.keys.count) section keys in Firebase")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: value)
            let decoded = try JSONDecoder().decode([String: FirebaseAlbumSection].self, from: jsonData)

            let activeSections = decoded.values.filter { $0.isActive }.sorted(by: { $0.id < $1.id })
            Logger.firebaseService.info("Successfully decoded \(activeSections.count) active sections")

            return activeSections
        } catch let error as DecodingError {
            Logger.firebaseService.error("Failed to decode sections from Firebase")
            switch error {
            case .keyNotFound(let key, let context):
                Logger.firebaseService.error("Missing key '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .typeMismatch(let type, let context):
                Logger.firebaseService.error("Type mismatch for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .valueNotFound(let type, let context):
                Logger.firebaseService.error("Value not found for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .dataCorrupted(let context):
                Logger.firebaseService.error("Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            @unknown default:
                Logger.firebaseService.error("Unknown decoding error: \(error)")
            }
            throw error
        } catch {
            Logger.firebaseService.error("Failed to process sections data: \(error.localizedDescription)")
            throw error
        }
    }

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

    public func saveAlbumData(albumId: String, albumData: FirebaseAlbumData) async throws {
        let ref = Database.database().reference().child("albums").child(albumId)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(albumData)
        let json = try JSONSerialization.jsonObject(with: jsonData)

        try await ref.setValue(json)
        Logger.firebaseService.info("Saved album data to Firebase for album: \(albumId)")
    }

    public func getUserRating(userId: String, albumId: String) async throws -> Double? {
        let ref = Database.database().reference()
            .child("users")
            .child(userId)
            .child("user_ratings")
            .child(albumId)
            .child("rating")

        let snapshot = try await ref.getData()

        guard snapshot.exists(), let rating = snapshot.value as? Double else {
            Logger.firebaseService.info("No user rating found for user: \(userId), album: \(albumId)")
            return nil
        }

        Logger.firebaseService.info("Fetched user rating for user: \(userId), album: \(albumId)")
        return rating
    }

    public func getUserRatedAlbumIds(userId: String) async throws -> [String] {
        let ref = Database.database().reference()
            .child("users")
            .child(userId)
            .child("user_ratings")

        let snapshot = try await ref.getData()

        guard snapshot.exists(), let ratingsData = snapshot.value as? [String: Any] else {
            Logger.firebaseService.info("No rated albums found for user: \(userId)")
            return []
        }

        Logger.firebaseService.info("Fetched \(ratingsData.count) rated albums for user: \(userId)")

        // Parse ratings with timestamps, handling both old (Double) and new (Dictionary) formats
        var ratingsWithTimestamp: [(albumId: String, timestamp: TimeInterval)] = []

        for (albumId, value) in ratingsData {
            let timestamp: TimeInterval

            if let ratingDict = value as? [String: Any],
               let storedTimestamp = ratingDict["timestamp"] as? TimeInterval {
                // New format: {rating: X, timestamp: Y}
                timestamp = storedTimestamp
            } else if value is Double {
                // Old format: just the rating number (no timestamp)
                // Use a default old timestamp so these appear last
                timestamp = 0
            } else {
                Logger.firebaseService.warning("Unknown format for album \(albumId), skipping")
                continue
            }

            ratingsWithTimestamp.append((albumId: albumId, timestamp: timestamp))
        }

        // Sort by timestamp descending (newest first)
        let sortedAlbumIds = ratingsWithTimestamp
            .sorted { $0.timestamp > $1.timestamp }
            .map { $0.albumId }

        Logger.firebaseService.debug("Sorted \(sortedAlbumIds.count) albums by timestamp (newest first)")
        return sortedAlbumIds
    }

    public func saveUserRating(userId: String, albumId: String, rating: Double, albumMetadata: (artist: String, title: String)? = nil) async throws -> (avgRating: Double, ratingCount: Int) {
        try await ensureAlbumExists(albumId: albumId, albumMetadata: albumMetadata)

        // Write to both Firebase nodes in parallel using task group
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.saveRatingToUserNode(userId: userId, albumId: albumId, rating: rating)
            }
            group.addTask {
                try await self.saveRatingToAlbumNode(userId: userId, albumId: albumId, rating: rating)
            }
            try await group.waitForAll()
        }

        let stats = try await calculateAlbumStats(userId: userId, albumId: albumId, rating: rating)
        try await updateAlbumStats(albumId: albumId, avgRating: stats.avgRating, ratingCount: stats.ratingCount)

        Logger.firebaseService.info("Saved rating \(rating) for album: \(albumId). Avg: \(stats.avgRating), Count: \(stats.ratingCount)")

        return stats
    }

    private func ensureAlbumExists(albumId: String, albumMetadata: (artist: String, title: String)?) async throws {
        let db = Database.database().reference()
        let albumRef = db.child("albums").child(albumId)
        let albumSnapshot = try await albumRef.getData()

        guard !albumSnapshot.exists(), let metadata = albumMetadata else {
            return
        }

        Logger.firebaseService.info("Creating new album in Firebase: \(albumId)")

        let newAlbumData: [String: Any] = [
            "artist": metadata.artist,
            "title": metadata.title,
            "createdAt": ServerValue.timestamp(),
            "avgRating": 0.0,
            "ratingCount": 0
        ]

        try await albumRef.setValue(newAlbumData)
        Logger.firebaseService.info("Created album: \(albumId) with artist: \(metadata.artist), title: \(metadata.title)")
    }

    private func saveRatingToUserNode(userId: String, albumId: String, rating: Double) async throws {
        let db = Database.database().reference()
        let userRatingRef = db.child("users").child(userId).child("user_ratings").child(albumId)

        // Save rating with timestamp for proper ordering
        let timestamp = Date().timeIntervalSince1970
        let ratingData: [String: Any] = [
            "rating": rating,
            "timestamp": timestamp
        ]

        try await userRatingRef.setValue(ratingData)
        Logger.firebaseService.debug("Saved rating \(rating) with timestamp \(timestamp) for album \(albumId)")
    }

    private func saveRatingToAlbumNode(userId: String, albumId: String, rating: Double) async throws {
        let db = Database.database().reference()
        let albumRatingRef = db.child("album_ratings").child(albumId).child(userId)
        try await albumRatingRef.setValue(rating)
    }

    private func calculateAlbumStats(userId: String, albumId: String, rating: Double) async throws -> (avgRating: Double, ratingCount: Int) {
        let db = Database.database().reference()
        let allRatingsRef = db.child("album_ratings").child(albumId)
        let snapshot = try await allRatingsRef.getData()

        let ratingsDict: [String: Double]
        if snapshot.exists(), let existingRatings = snapshot.value as? [String: Double] {
            ratingsDict = existingRatings
        } else {
            // First rating for this album
            ratingsDict = [userId: rating]
            Logger.firebaseService.info("First rating for album: \(albumId)")
        }

        let ratings = Array(ratingsDict.values)
        let avgRating = ratings.reduce(0.0, +) / Double(ratings.count)
        let ratingCount = ratings.count

        return (avgRating: avgRating, ratingCount: ratingCount)
    }

    private func updateAlbumStats(albumId: String, avgRating: Double, ratingCount: Int) async throws {
        // Update both stats in parallel using task group
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.updateAvgRating(albumId: albumId, avgRating: avgRating)
            }
            group.addTask {
                try await self.updateRatingCount(albumId: albumId, ratingCount: ratingCount)
            }
            // Wait for both tasks to complete
            try await group.waitForAll()
        }
    }

    private func updateAvgRating(albumId: String, avgRating: Double) async throws {
        let ref = Database.database().reference().child("albums").child(albumId).child("avgRating")
        try await ref.setValue(avgRating)
    }

    private func updateRatingCount(albumId: String, ratingCount: Int) async throws {
        let ref = Database.database().reference().child("albums").child(albumId).child("ratingCount")
        try await ref.setValue(ratingCount)
    }

    public func getUserProfile(userId: String) async throws -> FirebaseUserProfile? {
        let ref = Database.database().reference()
            .child("users")
            .child(userId)
            .child("profile")

        let snapshot = try await ref.getData()

        guard snapshot.exists(), let value = snapshot.value as? [String: Any] else {
            Logger.firebaseService.info("No user profile found for user: \(userId)")
            return nil
        }

        let jsonData = try JSONSerialization.data(withJSONObject: value)
        let decoded = try JSONDecoder().decode(FirebaseUserProfile.self, from: jsonData)

        Logger.firebaseService.info("Fetched user profile for user: \(userId)")
        return decoded
    }

    public func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws {
        let db = Database.database().reference()
        let userRef = db.child("users").child(userId)

        // Encode profile data
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(profile)
        let profileJson = try JSONSerialization.jsonObject(with: jsonData)

        // Create complete user structure if it doesn't exist
        let updates: [String: Any] = [
            "profile": profileJson,
            // Initialize user_ratings as empty object if it doesn't exist
            // This won't overwrite existing ratings
        ]

        // Check if user_ratings exists, if not create it
        let ratingsRef = userRef.child("user_ratings")
        let ratingsSnapshot = try await ratingsRef.getData()

        var allUpdates = updates
        if !ratingsSnapshot.exists() {
            // Create empty user_ratings node
            allUpdates["user_ratings"] = [String: Any]()
            Logger.firebaseService.info("Creating user_ratings node for user: \(userId)")
        }

        // Update all fields atomically
        try await userRef.updateChildValues(allUpdates)
        Logger.firebaseService.info("Saved user profile to Firebase for user: \(userId)")
    }
}

