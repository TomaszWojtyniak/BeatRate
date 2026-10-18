//
//  SpotifyLog.swift
//  SpotifyService
//

import Analytics
import OSLog

/// Every Spotify log line also goes to Crashlytics as a breadcrumb: connecting
/// Spotify is where users hit problems, and console logs never leave the phone.
/// Messages go out in plain text — never pass tokens or authorization codes.
nonisolated enum SpotifyLog {
    static func info(_ message: String) {
        Logger.spotifyService.info("\(message, privacy: .public)")
        CrashLogger.log("[spotify] \(message)")
    }

    static func error(_ message: String) {
        Logger.spotifyService.error("\(message, privacy: .public)")
        CrashLogger.log("[spotify] ERROR \(message)")
    }

    /// Spotify error bodies (`{"error":"invalid_grant",…}`) carry the actual
    /// reason a request was rejected. Truncated; never called on a 2xx body.
    static func body(_ data: Data) -> String {
        String(decoding: data.prefix(300), as: UTF8.self)
    }
}
