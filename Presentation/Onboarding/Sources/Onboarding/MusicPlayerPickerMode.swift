//
//  MusicPlayerPickerMode.swift
//  Onboarding
//

public enum MusicPlayerPickerMode: Sendable {
    /// Initial onboarding pick.
    case onboarding
    /// Settings change — dismisses itself once the pick lands.
    case change
}
