//
//  FirebaseBackends.swift
//  AnalyticsFirebase
//

#if os(iOS)
import Analytics
import FirebaseAnalytics
import FirebaseCrashlytics

// Firebase's class is spelled `FirebaseAnalytics.Analytics` because this
// package's own module is also called `Analytics`.

/// Sends `AnalyticsManager`'s calls to Firebase Analytics.
public struct FirebaseAnalyticsBackend: AnalyticsBackend {
    public init() {}

    public func setConsent(analyticsGranted: Bool) {
        // BeatRate serves no ads and runs against an EU database, so the three
        // ad consents stay denied — granting them would put ad-related data
        // collection on the App Privacy label for data we never collect.
        FirebaseAnalytics.Analytics.setConsent([
          .analyticsStorage: analyticsGranted ? .granted : .denied,
          .adStorage: .denied,
          .adUserData: .denied,
          .adPersonalization: .denied,
        ])
    }

    public func setCollectionEnabled(_ enabled: Bool) {
        FirebaseAnalytics.Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    public func resetData() {
        FirebaseAnalytics.Analytics.resetAnalyticsData()
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        FirebaseAnalytics.Analytics.setUserProperty(value, forName: name)
    }

    public func logEvent(_ name: String, parameters: [String: Any]?) {
        FirebaseAnalytics.Analytics.logEvent(name, parameters: parameters)
    }

    public func setUserID(_ userId: String?) {
        FirebaseAnalytics.Analytics.setUserID(userId)
    }
}

/// Sends `CrashLogger`'s calls to Crashlytics.
nonisolated public struct FirebaseCrashBackend: CrashBackend {
    public init() {}

    public func setCollectionEnabled(_ enabled: Bool) {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
    }

    public func setUserID(_ userId: String?) {
        Crashlytics.crashlytics().setUserID(userId)
    }

    public func record(_ error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }

    public func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    public func setCustomValue(_ value: String, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
}
#endif
