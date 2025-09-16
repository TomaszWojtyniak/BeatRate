//
//  AnalyticsManager.swift
//  Analytics
//
//  Created by Tomasz Wojtyniak on 28/05/2025.
//

import FirebaseAnalytics
import SwiftUI
import OSLog

@MainActor
public final class AnalyticsManager {
    public static let shared = AnalyticsManager()
    
    private var isEnabled: Bool = true
    
    private init() {
        Logger.analytics.info("Analytics Manager initialized")
    }
    
    public func setAnalyticsEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Analytics.setConsent([
          .analyticsStorage: .granted,
          .adStorage: .granted,
          .adUserData: .granted,
          .adPersonalization: .granted,
        ])
        Analytics.setAnalyticsCollectionEnabled(enabled)
        Logger.analytics.info("Analytics collection \(enabled ? "enabled" : "disabled")")
    }
    
    public func setUserProperty(_ value: String?, forName name: String) {
        guard isEnabled else { return }
        
        Analytics.setUserProperty(value, forName: name)
        
        Logger.analytics.debug("Set user property: \(name) = \(value ?? "nil")")
    }
    
    public func setUserId(_ userId: String?) {
        guard isEnabled else { return }
        
        Analytics.setUserID(userId)
        
        Logger.analytics.debug("Set user ID: \(userId ?? "nil")")
    }
}
