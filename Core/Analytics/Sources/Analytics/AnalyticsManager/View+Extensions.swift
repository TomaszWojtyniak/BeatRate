//
//  View+Extensions.swift
//  Analytics
//
//  Created by Tomasz Wojtyniak on 28/05/2025.
//
import SwiftUI

extension View {
    public func trackScreenView(_ screenName: String, screenClass: String? = nil) -> some View {
        modifier(AnalyticsViewModifier(screenName: screenName, screenClass: screenClass))
    }
    
    public func trackButtonTap(_ buttonName: String, location: String? = nil) -> some View {
        self.onTapGesture {
            Task {
                await AnalyticsManager.shared.trackButtonTap(buttonName, location: location)
            }
        }
    }
}
