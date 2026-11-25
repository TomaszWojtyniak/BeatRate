//
//  CrashLogger.swift
//  Analytics
//
//  Created by Tomasz Wojtyniak on 28/05/2025.
//

import Foundation
import OSLog
import Synchronization

@MainActor
public final class CrashLogger {
    /// Writes to OSLog only until the app installs Crashlytics with ``use(_:)``.
    nonisolated public static let shared = CrashLogger(backend: NoCrashBackend())

    nonisolated private let backend: Mutex<any CrashBackend>
    /// Domains already sent by ``report(_:_:to:)`` this launch.
    nonisolated private let reported = Mutex<Set<String>>([])

    /// Tests pass a recording stub; the app installs Crashlytics on `shared` with ``use(_:)``.
    nonisolated public init(backend: any CrashBackend) {
        self.backend = Mutex(backend)
    }

    /// Sends everything logged from now on to `backend`.
    nonisolated public func use(_ backend: any CrashBackend) {
        self.backend.withLock { $0 = backend }
    }

    /// Read under the lock, called outside it, so a backend never runs while holding it.
    nonisolated private var current: any CrashBackend {
        backend.withLock { $0 }
    }
    
    public func configure() {
        current.setCollectionEnabled(true)
    }
    
    /// Pass nil on logout so later reports aren't attributed to that user.
    public func setUserIdentifier(_ identifier: String?) {
        current.setUserID(identifier)
        Logger.crashLogger.info("User identifier set: \(identifier ?? "nil")")
    }

    public func reportToCrashlytics(error: Error) {
        current.record(error)
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
        current.log("[\(file.prefix { $0 != "/" })] \(message)")
    }

    nonisolated func setValue(_ value: String, forKey key: String) {
        current.setCustomValue(value, forKey: key)
    }

    nonisolated func report(_ domain: String, _ reason: String, to logger: Logger?) {
        log(reason, to: logger, level: .error, file: domain)  // tagged [domain] instead of [module]
        guard reported.withLock({ $0.insert(domain).inserted }) else { return }
        current.record(NSError(
            domain: "BeatRate.\(domain)",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: reason]
        ))
    }
}

/// The Crashlytics calls `CrashLogger` makes, so tests can record them instead.
nonisolated public protocol CrashBackend: Sendable {
    func setCollectionEnabled(_ enabled: Bool)
    func setUserID(_ userId: String?)
    func record(_ error: Error)
    func log(_ message: String)
    func setCustomValue(_ value: String, forKey key: String)
}

/// Until the app installs Crashlytics there is nowhere else to send anything:
/// `CrashLogger` writes to OSLog itself. The headless CLI keeps it for good.
nonisolated public struct NoCrashBackend: CrashBackend {
    public init() {}
    public func setCollectionEnabled(_ enabled: Bool) {}
    public func setUserID(_ userId: String?) {}
    public func record(_ error: Error) {}
    public func log(_ message: String) {}
    public func setCustomValue(_ value: String, forKey key: String) {}
}
