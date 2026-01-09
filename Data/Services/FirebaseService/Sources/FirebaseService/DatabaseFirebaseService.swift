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
        let snapshot = try await ref.getData()

        guard let value = snapshot.value as? [String: Any] else {
            return []
        }

        let jsonData = try JSONSerialization.data(withJSONObject: value)
        let decoded = try JSONDecoder().decode([String: FirebaseAlbumSection].self, from: jsonData)

        return decoded.values.filter { $0.isActive }.sorted(by: { $0.id < $1.id })
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

        let snapshot = try await ref.getData()

        guard snapshot.exists(), let rating = snapshot.value as? Double else {
            Logger.firebaseService.info("No user rating found for user: \(userId), album: \(albumId)")
            return nil
        }

        Logger.firebaseService.info("Fetched user rating for user: \(userId), album: \(albumId)")
        return rating
    }

    public func saveUserRating(userId: String, albumId: String, rating: Double, albumMetadata: (artist: String, title: String)? = nil) async throws -> (avgRating: Double, ratingCount: Int) {
        try await ensureAlbumExists(albumId: albumId, albumMetadata: albumMetadata)

        // Write to both Firebase nodes in parallel
        async let userNodeTask = saveRatingToUserNode(userId: userId, albumId: albumId, rating: rating)
        async let albumNodeTask = saveRatingToAlbumNode(userId: userId, albumId: albumId, rating: rating)
        try await userNodeTask
        try await albumNodeTask

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
        try await userRatingRef.setValue(rating)
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
        let db = Database.database().reference()
        let albumRef = db.child("albums").child(albumId)

        // Update both stats in parallel
        async let avgRatingTask = albumRef.child("avgRating").setValue(avgRating)
        async let ratingCountTask = albumRef.child("ratingCount").setValue(ratingCount)
        try await avgRatingTask
        try await ratingCountTask
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

