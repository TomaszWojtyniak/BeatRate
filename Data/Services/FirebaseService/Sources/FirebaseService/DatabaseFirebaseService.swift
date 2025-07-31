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
}

public actor DatabaseFirebaseService: DatabaseFirebaseServiceProtocol {
    public static let shared = DatabaseFirebaseService()
    let analyticsManager: AnalyticsManager
    let crashLogger: CrashLogger
    static var logger: Logger {
        return Logger.for(Self.self)
    }
    
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
}

