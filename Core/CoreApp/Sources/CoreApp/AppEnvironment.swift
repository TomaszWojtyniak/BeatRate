import Foundation

/// Represents the app's runtime environment based on the active scheme
public enum AppEnvironment {
    case production
    case development

    /// Returns the current app environment based on the bundle identifier
    nonisolated public static var current: AppEnvironment {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return .production
        }
        return bundleID.contains("development") ? .development : .production
    }

    /// Returns true if running in development scheme
    nonisolated public var isDevelopment: Bool {
        switch self {
        case .development: true
        case .production: false
        }
    }

    /// Returns true if running in production scheme
    nonisolated public var isProduction: Bool {
        switch self {
        case .production: true
        case .development: false
        }
    }

    /// Returns the Firebase Realtime Database URL for the current environment
    nonisolated public var firebaseDatabaseUrl: String {
        switch self {
        case .production:
            "https://beatrate-production-9e5aa-6fcd5.europe-west1.firebasedatabase.app/"
        case .development:
            "https://beatrate-9e5aa-default-rtdb.firebaseio.com/"
        }
    }
}
