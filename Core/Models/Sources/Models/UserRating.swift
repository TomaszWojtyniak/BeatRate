//
//  UserRating.swift
//  Models
//
//  Created by Claude on 15/01/2026.
//

import Foundation

public struct UserRating: Codable, Sendable {
    public let rating: Double
    public let timestamp: TimeInterval

    public init(rating: Double, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.rating = rating
        self.timestamp = timestamp
    }

    public var date: Date {
        Date(timeIntervalSince1970: timestamp)
    }
}
