//
//  CrashLogger.swift
//  Analytics
//
//  Created by Tomasz Wojtyniak on 28/05/2025.
//

import Foundation
import OSLog
import FirebaseCrashlytics

@MainActor
public class CrashLogger {
    public static let shared = CrashLogger()

    private init() {

    }
    
    public func configure() {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    }
    
    public func setUserIdentifier(_ identifier: String) {
        Crashlytics.crashlytics().setUserID(identifier)
        Logger.crashLogger.info("User identifier set: \(identifier)")
    }

    public func reportToCrashlytics(error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }
}
