//
//  MusicPlayerPickerMode.swift
//  Onboarding
//

public enum MusicPlayerPickerMode: Sendable {
    /// Initial onboarding pick — selecting Spotify auto-runs the Spotify connect flow.
    case onboarding
    /// Settings change — persists selection. If switching to a provider that isn't connected,
    /// kicks off that connect flow.
    case change
}
