//
//  Track.swift
//  Models
//

import Foundation

public struct Track: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let trackNumber: Int?
    public let discNumber: Int?
    public let duration: TimeInterval?
    public let isExplicit: Bool

    public init(id: String,
                title: String,
                trackNumber: Int?,
                discNumber: Int?,
                duration: TimeInterval?,
                isExplicit: Bool) {
        self.id = id
        self.title = title
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.duration = duration
        self.isExplicit = isExplicit
    }
}
