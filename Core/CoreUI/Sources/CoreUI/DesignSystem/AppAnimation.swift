//
//  AppAnimation.swift
//  CoreUI
//
//  Three named animation curves cover the entire app. Use these instead of
//  hand-rolling `.easeInOut(duration: 0.2)` so timing stays consistent.
//
//  Usage:
//      withAnimation(AppAnimation.quick) { … }
//      .animation(AppAnimation.smooth, value: someState)
//

import SwiftUI

public enum AppAnimation {
    /// 0.20s ease-in-out — fast feedback for state flips (loading blur, opacity toggles).
    public static let quick:    Animation = .easeInOut(duration: 0.2)
    /// 0.25s ease — short transitions (the "Saved" flash in/out).
    public static let standard: Animation = .easeInOut(duration: 0.25)
    /// 0.40s ease-in-out — value-driven crossfades (artwork-tint reveal, colour swaps).
    public static let smooth:   Animation = .easeInOut(duration: 0.4)
}
