//
//  AnalyticsManager.swift
//  Analytics
//
//  Created by Tomasz Wojtyniak on 28/05/2025.
//

import FirebaseAnalytics
import SwiftUI
import OSLog

@globalActor
public actor AnalyticsManager {
    public static let shared = AnalyticsManager()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.beat.rate", category: "Analytics")
    private var isEnabled: Bool = true
    private var debugMode: Bool = false
    
    private init() {
        logger.info("Analytics Manager initialized")
    }
    
    public func configure(debugMode: Bool = false) {
        self.debugMode = debugMode
        logger.info("Analytics Manager configured with debug mode: \(debugMode)")
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
        logger.info("Analytics collection \(enabled ? "enabled" : "disabled")")
    }
    
    public func track(_ event: AnalyticsEvent) {
        guard isEnabled else {
            logger.debug("Analytics disabled, skipping event: \(event.name)")
            return
        }
        
        let eventName = event.name
        let parameters = event.parameters
        
        if debugMode {
            logger.debug("Tracking event: \(eventName) with parameters: \(String(describing: parameters))")
        }
        
        Analytics.logEvent(eventName, parameters: parameters)
    }
    
    public func track(_ event: AppAnalyticsEvent) {
        track(event as AnalyticsEvent)
    }
    
    public func setUserProperty(_ value: String?, forName name: String) {
        guard isEnabled else { return }
        
        Analytics.setUserProperty(value, forName: name)
        
        if debugMode {
            logger.debug("Set user property: \(name) = \(value ?? "nil")")
        }
    }
    
    public func setUserId(_ userId: String?) {
        guard isEnabled else { return }
        
        Analytics.setUserID(userId)
        
        if debugMode {
            logger.debug("Set user ID: \(userId ?? "nil")")
        }
    }
    
    func trackScreenView(_ screenName: String, screenClass: String? = nil) {
        track(AppAnalyticsEvent.screenView(screenName: screenName, screenClass: screenClass))
    }

    func trackButtonTap(_ buttonName: String, location: String? = nil) {
        track(AppAnalyticsEvent.buttonTap(buttonName: buttonName, location: location))
    }
}
