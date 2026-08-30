//
//  DatabaseFirebaseService.swift
//  FirebaseService
//
//  Created by Tomasz Wojtyniak on 29/07/2025.
//

import SwiftUI
import Analytics
// TODO: Remove @preconcurrency when Firebase SDK adds Sendable support
// Firebase SDK is internally thread-safe but DatabaseReference is not marked Sendable
// Last checked: 2025-01 (firebase-ios-sdk 11.13.0)
@preconcurrency import FirebaseDatabase
import OSLog
import Models
import CoreApp

public protocol DatabaseFirebaseServiceProtocol: Sendable {
    func fetchSections() async throws -> [FirebaseAlbumSection]
    func fetchAlbumData(albumId: String) async throws -> FirebaseAlbumData?
    func saveAlbumData(albumId: String, albumData: FirebaseAlbumData) async throws
    func getUserRating(userId: String, albumId: String) async throws -> Double?
    func getUserRatedAlbumIds(userId: String) async throws -> [String]
    func getAllUserRatings(userId: String) async throws -> [String: Double]
    func getUserRatingsSorted(userId: String) async throws -> [(albumId: String, rating: Double)]
    func saveUserRating(userId: String, albumId: String, rating: Double, albumMetadata: (artist: String, title: String)?) async throws -> (avgRating: Double, ratingCount: Int)
    func removeUserRating(userId: String, albumId: String) async throws -> (avgRating: Double, ratingCount: Int)
    func getUserProfile(userId: String) async throws -> FirebaseUserProfile?
    func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws
    func getFavoriteAlbumIds(userId: String) async throws -> [String]
    func saveFavoriteAlbumIds(userId: String, albumIds: [String]) async throws
    func deleteUserData(userId: String) async throws
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

    /// Returns the Firebase Database instance configured for the current environment
    private var database: Database {
        Database.database(url: AppEnvironment.current.firebaseDatabaseUrl)
    }
    
    public func fetchSections() async throws -> [FirebaseAlbumSection] {
        let ref = database.reference().child("sections")

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
        let ref = database.reference().child("albums").child(albumId)
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
        let ref = database.reference().child("albums").child(albumId)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(albumData)
        let json = try JSONSerialization.jsonObject(with: jsonData)

        try await ref.setValue(json)
        Logger.firebaseService.info("Saved album data to Firebase for album: \(albumId)")
    }

    public func getUserRating(userId: String, albumId: String) async throws -> Double? {
        let ref = database.reference()
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
        let ref = database.reference()
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

    /// Fetches every rating the user has made in a single read, returning an
    /// `albumId -> rating` map. Handles both the new `{rating, timestamp}` format
    /// and the legacy bare-`Double` format.
    public func getAllUserRatings(userId: String) async throws -> [String: Double] {
        let ref = database.reference()
            .child("users")
            .child(userId)
            .child("user_ratings")

        let snapshot = try await ref.getData()

        guard snapshot.exists(), let ratingsData = snapshot.value as? [String: Any] else {
            Logger.firebaseService.info("No user ratings found for user: \(userId)")
            return [:]
        }

        var ratings: [String: Double] = [:]
        for (albumId, value) in ratingsData {
            if let ratingDict = value as? [String: Any], let rating = ratingDict["rating"] as? Double {
                ratings[albumId] = rating              // New format: {rating, timestamp}
            } else if let rating = value as? Double {
                ratings[albumId] = rating              // Legacy format: bare number
            } else {
                Logger.firebaseService.warning("Unknown rating format for album \(albumId), skipping")
            }
        }

        Logger.firebaseService.info("Fetched \(ratings.count) user ratings for user: \(userId)")
        return ratings
    }

    /// Single read of `user_ratings` returning every rating with its album id,
    /// newest-first by timestamp. Lets a caller that needs *both* the rated-album
    /// ordering and the rating values read the node once instead of twice.
    public func getUserRatingsSorted(userId: String) async throws -> [(albumId: String, rating: Double)] {
        let ref = database.reference()
            .child("users")
            .child(userId)
            .child("user_ratings")

        let snapshot = try await ref.getData()

        guard snapshot.exists(), let ratingsData = snapshot.value as? [String: Any] else {
            Logger.firebaseService.info("No user ratings found for user: \(userId)")
            return []
        }

        var entries: [(albumId: String, rating: Double, timestamp: TimeInterval)] = []
        for (albumId, value) in ratingsData {
            if let dict = value as? [String: Any], let rating = dict["rating"] as? Double {
                entries.append((albumId, rating, (dict["timestamp"] as? TimeInterval) ?? 0))
            } else if let rating = value as? Double {
                entries.append((albumId, rating, 0))          // legacy bare number
            } else {
                Logger.firebaseService.warning("Unknown rating format for album \(albumId), skipping")
            }
        }

        return entries
            .sorted { $0.timestamp > $1.timestamp }
            .map { (albumId: $0.albumId, rating: $0.rating) }
    }

    public func saveUserRating(userId: String, albumId: String, rating: Double, albumMetadata: (artist: String, title: String)? = nil) async throws -> (avgRating: Double, ratingCount: Int) {
        try await ensureAlbumExists(albumId: albumId, albumMetadata: albumMetadata)

        // One atomic multi-location write, mirroring `removeUserRating`. Writing
        // the two nodes separately can half-succeed, and an `album_ratings` entry
        // with no matching user-node entry is invisible to account deletion —
        // which walks the user node — so it would outlive the account forever.
        try await database.reference().updateChildValues([
            "/users/\(userId)/user_ratings/\(albumId)": [
                "rating": rating,
                "timestamp": Date().timeIntervalSince1970
            ],
            "/album_ratings/\(albumId)/\(userId)": rating
        ])

        let stats = try await recalculateAlbumStats(albumId: albumId)

        Logger.firebaseService.info("Saved rating \(rating) for album: \(albumId). Avg: \(stats.avgRating), Count: \(stats.ratingCount)")

        return stats
    }

    /// Removes a user's rating for an album — their own entry and their
    /// contribution to the shared aggregate — then recomputes the album's stats
    /// from the ratings that remain. Returns the fresh avg/count.
    public func removeUserRating(userId: String, albumId: String) async throws -> (avgRating: Double, ratingCount: Int) {
        try await database.reference().updateChildValues([
            "/users/\(userId)/user_ratings/\(albumId)": NSNull(),
            "/album_ratings/\(albumId)/\(userId)": NSNull()
        ])

        let stats = try await recalculateAlbumStats(albumId: albumId)
        Logger.firebaseService.info("Removed rating for album: \(albumId). Avg: \(stats.avgRating), Count: \(stats.ratingCount)")
        return stats
    }

    private func ensureAlbumExists(albumId: String, albumMetadata: (artist: String, title: String)?) async throws {
        let db = database.reference()
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

    /// Recomputes an album's aggregate from whatever ratings currently remain in
    /// `album_ratings`. Used after a rating is removed (e.g. account deletion or
    /// a user clearing their rating); an empty node zeroes the stats.
    @discardableResult
    private func recalculateAlbumStats(albumId: String) async throws -> (avgRating: Double, ratingCount: Int) {
        let snapshot = try await database.reference().child("album_ratings").child(albumId).getData()

        // Per-entry cast, not `as? [String: Double]`: that is all-or-nothing, so a
        // single malformed child would yield an empty list and wipe every other
        // user's contribution. Ignore 0/null entries — 0 means "not rated".
        let values = (snapshot.value as? [String: Any])?
            .values
            .compactMap { $0 as? Double }
            .filter { $0 > 0 } ?? []
        let stats: (avgRating: Double, ratingCount: Int) = values.isEmpty
            ? (0.0, 0)
            : (values.reduce(0.0, +) / Double(values.count), values.count)

        try await updateAlbumStats(albumId: albumId, avgRating: stats.avgRating, ratingCount: stats.ratingCount)
        return stats
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
        let ref = database.reference().child("albums").child(albumId).child("avgRating")
        try await ref.setValue(avgRating)
    }

    private func updateRatingCount(albumId: String, ratingCount: Int) async throws {
        let ref = database.reference().child("albums").child(albumId).child("ratingCount")
        try await ref.setValue(ratingCount)
    }

    public func getUserProfile(userId: String) async throws -> FirebaseUserProfile? {
        let ref = database.reference()
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
        let db = database.reference()
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

    // MARK: - Favorites

    /// Reads the user's ordered favorite album IDs from `users/{uid}/favorites`.
    /// The node is always written as a contiguous array, so RTDB returns it as
    /// `[Any]`, preserving order.
    public func getFavoriteAlbumIds(userId: String) async throws -> [String] {
        let ref = database.reference()
            .child("users")
            .child(userId)
            .child("favorites")

        let snapshot = try await ref.getData()

        guard snapshot.exists(), let array = snapshot.value as? [Any] else {
            Logger.firebaseService.info("No favorites found for user: \(userId)")
            return []
        }

        return array.compactMap { $0 as? String }
    }

    /// Overwrites the user's favorites with the given ordered IDs. An empty list
    /// removes the node (deletions aren't subject to `.validate` rules).
    public func saveFavoriteAlbumIds(userId: String, albumIds: [String]) async throws {
        let ref = database.reference()
            .child("users")
            .child(userId)
            .child("favorites")

        if albumIds.isEmpty {
            try await ref.removeValue()
        } else {
            try await ref.setValue(albumIds)
        }
        Logger.firebaseService.info("Saved \(albumIds.count) favorites for user: \(userId)")
    }

    /// Wipes every trace of a user for account deletion: their whole `users/<id>`
    /// node (profile, ratings, favorites) plus their per-album entries in the
    /// shared `album_ratings` aggregate. The deletes go out as one atomic
    /// multi-location update; the aggregate recompute that follows does not.
    public func deleteUserData(userId: String) async throws {
        let ratedAlbumIds = try await getUserRatedAlbumIds(userId: userId)

        var updates: [String: Any] = ["/users/\(userId)": NSNull()]
        for albumId in ratedAlbumIds {
            updates["/album_ratings/\(albumId)/\(userId)"] = NSNull()
        }

        try await database.reference().updateChildValues(updates)
        Logger.firebaseService.info("Deleted RTDB data for user: \(userId) (\(ratedAlbumIds.count) album ratings)")

        // Recompute each affected album's aggregate from the ratings that remain.
        // Concurrent, because until an album's turn comes its public avg/count
        // still counts the deleted user — and if the app dies mid-pass that
        // stale total sticks until someone else rates the album.
        // Best-effort: a stale average is a data-quality issue, not a reason to
        // abort account deletion, so failures are logged and skipped.
        // ponytail: non-atomic read-then-write, same race as the rating path; a
        // Cloud Function on album_ratings delete would remove the race entirely.
        _ = await ratedAlbumIds.concurrentCompactMap(maxConcurrent: 8) { albumId -> Bool? in
            do {
                try await self.recalculateAlbumStats(albumId: albumId)
                return true
            } catch {
                Logger.firebaseService.error("Failed to recompute stats for album \(albumId): \(error.localizedDescription)")
                return nil
            }
        }
    }
}

