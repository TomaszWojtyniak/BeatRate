//
//  MusicPlayer.swift
//  Models
//

import Foundation

public enum MusicPlayer: String, Codable, Sendable, CaseIterable {
    case appleMusic
    case spotify

    public var displayName: String {
        switch self {
        case .appleMusic: "Apple Music"
        case .spotify: "Spotify"
        }
    }
}
