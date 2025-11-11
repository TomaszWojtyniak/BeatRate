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

    @MainActor
    public func saveAlbumData(albumId: String, albumData: FirebaseAlbumData) async throws {
        let ref = Database.database().reference().child("albums").child(albumId)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(albumData)
        let json = try JSONSerialization.jsonObject(with: jsonData)

        try await ref.setValue(json)
        Logger.firebaseService.info("Saved album data to Firebase for album: \(albumId)")
    }

    @MainActor
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

    @MainActor
    public func saveUserRating(userId: String, albumId: String, rating: Double, albumMetadata: (artist: String, title: String)? = nil) async throws -> (avgRating: Double, ratingCount: Int) {
        let db = Database.database().reference()

        // 0. Ensure album exists in Firebase (create if needed)
        let albumRef = db.child("albums").child(albumId)
        let albumSnapshot = try await albumRef.getData()

        if !albumSnapshot.exists(), let metadata = albumMetadata {
            // Album doesn't exist - create it with required fields
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

        // 1. Save to users/{userId}/user_ratings/{albumId}
        let userRatingRef = db.child("users").child(userId).child("user_ratings").child(albumId)
        try await userRatingRef.setValue(rating)

        // 2. Save to album_ratings/{albumId}/{userId}
        let albumRatingRef = db.child("album_ratings").child(albumId).child(userId)
        try await albumRatingRef.setValue(rating)

        // 3. Recalculate album average rating
        let allRatingsRef = db.child("album_ratings").child(albumId)
        let snapshot = try await allRatingsRef.getData()

        // Handle both existing ratings and first rating case
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

        // 4. Update album avgRating and ratingCount
        try await albumRef.child("avgRating").setValue(avgRating)
        try await albumRef.child("ratingCount").setValue(ratingCount)

        Logger.firebaseService.info("Saved rating \(rating) for album: \(albumId). Avg: \(avgRating), Count: \(ratingCount)")

        // Return the calculated values
        return (avgRating: avgRating, ratingCount: ratingCount)
    }
}

