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
    
    // Off until the user opts in: GDPR needs consent before any analytics
    // identifier is stored. Info.plist's FIREBASE_ANALYTICS_COLLECTION_ENABLED
    // keeps the SDK itself quiet until then.
    private var isEnabled: Bool = false

    private static let consentKey = "analyticsConsent"
    private let defaults: UserDefaults
    private let backend: AnalyticsBackend

    init(defaults: UserDefaults = .standard, backend: AnalyticsBackend = FirebaseAnalyticsBackend()) {
        self.defaults = defaults
        self.backend = backend
        Logger.analytics.info("Analytics Manager initialized")
    }

    /// The user's answer to the consent prompt; nil until they've been asked.
    public var consent: Bool? {
        defaults.object(forKey: Self.consentKey) as? Bool
    }

    /// Records the user's choice and applies it. Revoking also wipes the
    /// analytics instance ID so nothing collected so far stays linked to them.
    public func setConsent(_ granted: Bool) {
        defaults.set(granted, forKey: Self.consentKey)
        setAnalyticsEnabled(granted)
        if !granted {
            backend.resetData()
        }
    }

    public func setAnalyticsEnabled(_ enabled: Bool) {
        isEnabled = enabled
        backend.setConsent(analyticsGranted: enabled)
        backend.setCollectionEnabled(enabled)
        Logger.analytics.info("Analytics collection \(enabled ? "enabled" : "disabled")")
    }
    
    public func setUserProperty(_ value: String?, forName name: String) {
        guard isEnabled else { return }
        
        backend.setUserProperty(value, forName: name)
        
        Logger.analytics.debug("Set user property: \(name) = \(value ?? "nil")")
    }
    
    public func log(_ event: AnalyticsEvent) {
        guard isEnabled else { return }

        let parameters = event.parameters
        backend.logEvent(event.name, parameters: parameters.isEmpty ? nil : parameters)

        Logger.analytics.debug("Logged event: \(event.name) \(parameters)")
    }

    public func setUserId(_ userId: String?) {
        guard isEnabled else { return }
        
        backend.setUserID(userId)
        
        Logger.analytics.debug("Set user ID: \(userId ?? "nil")")
    }
}

/// The Firebase calls `AnalyticsManager` makes, so tests can record them instead.
protocol AnalyticsBackend {
    func setConsent(analyticsGranted: Bool)
    func setCollectionEnabled(_ enabled: Bool)
    func resetData()
    func setUserProperty(_ value: String?, forName name: String)
    func logEvent(_ name: String, parameters: [String: Any]?)
    func setUserID(_ userId: String?)
}

struct FirebaseAnalyticsBackend: AnalyticsBackend {
    func setConsent(analyticsGranted: Bool) {
        // BeatRate serves no ads and runs against an EU database, so the three
        // ad consents stay denied — granting them would put ad-related data
        // collection on the App Privacy label for data we never collect.
        Analytics.setConsent([
          .analyticsStorage: analyticsGranted ? .granted : .denied,
          .adStorage: .denied,
          .adUserData: .denied,
          .adPersonalization: .denied,
        ])
    }

    func setCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    func resetData() {
        Analytics.resetAnalyticsData()
    }

    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    func logEvent(_ name: String, parameters: [String: Any]?) {
        Analytics.logEvent(name, parameters: parameters)
    }

    func setUserID(_ userId: String?) {
        Analytics.setUserID(userId)
    }
}
