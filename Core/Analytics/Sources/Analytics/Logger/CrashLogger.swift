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
    nonisolated public static let shared = CrashLogger(backend: FirebaseCrashBackend())

    nonisolated private let backend: CrashBackend
    /// Domains already sent by ``report(_:_:to:)`` this launch.
    nonisolated private let reported = Mutex<Set<String>>([])

    nonisolated init(backend: CrashBackend) {
        self.backend = backend
    }
    
    public func configure() {
        backend.setCollectionEnabled(true)
    }
    
    /// Pass nil on logout so later reports aren't attributed to that user.
    public func setUserIdentifier(_ identifier: String?) {
        backend.setUserID(identifier)
        Logger.crashLogger.info("User identifier set: \(identifier ?? "nil")")
    }

    public func reportToCrashlytics(error: Error) {
        backend.record(error)
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
        shared.log(message, to: logger, level: level, file: file)
    }

    /// Custom key attached to every later report this session, so each one
    /// shows the state it happened in (auth status, recents outcome, …).
    nonisolated public static func setValue(_ value: String, forKey key: String) {
        shared.setValue(value, forKey: key)
    }

    /// Non-fatal with a readable reason, for outcomes that aren't a thrown error
    /// (denied permission, empty list) or need context the error lacks. The
    /// console groups them by `domain`; the reason is in the event's logs.
    /// Each domain goes out once per launch — reasons carry IDs and errors, so
    /// they'd never repeat exactly. Crashlytics keeps only the latest 8
    /// non-fatals per session; later ones stay as breadcrumbs.
    nonisolated public static func report(_ domain: String, _ reason: String, to logger: Logger? = nil) {
        shared.report(domain, reason, to: logger)
    }

    nonisolated func log(_ message: String, to logger: Logger?, level: OSLogType, file: String) {
        logger?.log(level: level, "\(message, privacy: .public)")
        backend.log("[\(file.prefix { $0 != "/" })] \(message)")
    }

    nonisolated func setValue(_ value: String, forKey key: String) {
        backend.setCustomValue(value, forKey: key)
    }

    nonisolated func report(_ domain: String, _ reason: String, to logger: Logger?) {
        log(reason, to: logger, level: .error, file: domain)  // tagged [domain] instead of [module]
        guard reported.withLock({ $0.insert(domain).inserted }) else { return }
        backend.record(NSError(
            domain: "BeatRate.\(domain)",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: reason]
        ))
    }
}

/// The Crashlytics calls `CrashLogger` makes, so tests can record them instead.
nonisolated protocol CrashBackend: Sendable {
    func setCollectionEnabled(_ enabled: Bool)
    func setUserID(_ userId: String?)
    func record(_ error: Error)
    func log(_ message: String)
    func setCustomValue(_ value: String, forKey key: String)
}

nonisolated struct FirebaseCrashBackend: CrashBackend {
    func setCollectionEnabled(_ enabled: Bool) {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
    }

    func setUserID(_ userId: String?) {
        Crashlytics.crashlytics().setUserID(userId)
    }

    func record(_ error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }

    func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    func setCustomValue(_ value: String, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
}
