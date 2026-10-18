//
//  CrashLogger.swift
//  Analytics
//
//  Created by Tomasz Wojtyniak on 28/05/2025.
//

import Foundation
import OSLog
import FirebaseCrashlytics
import Synchronization

@MainActor
public final class CrashLogger {
    public static let shared = CrashLogger()

    private init() {

    }
    
    public func configure() {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    }
    
    /// Pass nil on logout so later reports aren't attributed to that user.
    public func setUserIdentifier(_ identifier: String?) {
        Crashlytics.crashlytics().setUserID(identifier)
        Logger.crashLogger.info("User identifier set: \(identifier ?? "nil")")
    }

    public func reportToCrashlytics(error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }

    /// Writes `message` to `logger` and leaves it as a Crashlytics breadcrumb,
    /// tagged with the calling module. Breadcrumbs ride along with the next
    /// crash or non-fatal of this session, never alone. The text goes to Google
    /// as-is (hence `.public` in the console too): no PII, tokens or codes.
    /// Static and nonisolated so actors can call it without hopping to main.
    nonisolated public static func log(
        _ message: String,
        to logger: Logger? = nil,
        level: OSLogType = .error,
        file: String = #fileID
    ) {
        logger?.log(level: level, "\(message, privacy: .public)")
        Crashlytics.crashlytics().log("[\(file.prefix { $0 != "/" })] \(message)")
    }

    /// Custom key attached to every later report this session, so each one
    /// shows the state it happened in (auth status, recents outcome, …).
    nonisolated public static func setValue(_ value: String, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    /// Non-fatal with a readable reason, for outcomes that aren't a thrown error
    /// (denied permission, empty list) or need context the error lacks. The
    /// console groups them by `domain`; the reason is in the event's logs.
    /// Each domain+reason goes out once per launch: Crashlytics keeps only the
    /// latest 8 non-fatals per session, so a repeat must not push out the rest.
    nonisolated public static func report(_ domain: String, _ reason: String, to logger: Logger? = nil) {
        log(reason, to: logger, file: domain)  // tagged [domain] instead of [module]
        guard reported.withLock({ $0.insert("\(domain)|\(reason)").inserted }) else { return }
        Crashlytics.crashlytics().record(error: NSError(
            domain: "BeatRate.\(domain)",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: reason]
        ))
    }

    nonisolated private static let reported = Mutex<Set<String>>([])
}
