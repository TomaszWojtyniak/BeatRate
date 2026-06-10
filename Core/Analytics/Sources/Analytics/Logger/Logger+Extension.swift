//
//  Logger+Extension.swift
//  Analytics
//
//  Created by Tomasz Wojtyniak on 30/05/2025.
//

import OSLog

public extension Logger {
    private nonisolated static let subsystem = "BeatRate"

    nonisolated static let analytics = Logger(subsystem: subsystem, category: "analytics")

    nonisolated static let crashLogger = Logger(subsystem: subsystem, category: "crashLogger")

    nonisolated static let homeRepository = Logger(subsystem: subsystem, category: "homeRepository")

    nonisolated static let musicRepository = Logger(subsystem: subsystem, category: "musicRepository")

    nonisolated static let musicService = Logger(subsystem: subsystem, category: "musicKit")

    nonisolated static let loginRepository = Logger(subsystem: subsystem, category: "loginRepository")

    nonisolated static let loginUseCases = Logger(subsystem: subsystem, category: "loginUseCases")

    nonisolated static let firebaseService = Logger(subsystem: subsystem, category: "firebaseService")

    nonisolated static let home = Logger(subsystem: subsystem, category: "home")

    nonisolated static let login = Logger(subsystem: subsystem, category: "login")

    nonisolated static let app = Logger(subsystem: subsystem, category: "app")

    nonisolated static let splash = Logger(subsystem: subsystem, category: "splash")

    nonisolated static let albumDetails = Logger(subsystem: subsystem, category: "albumDetails")

    nonisolated static let account = Logger(subsystem: subsystem, category: "account")

    nonisolated static let accountRepository = Logger(subsystem: subsystem, category: "accountRepository")

    nonisolated static let settings = Logger(subsystem: subsystem, category: "settings")

    nonisolated static let swiftDataManager = Logger(subsystem: subsystem, category: "swiftDataManager")

    nonisolated static let spotifyService = Logger(subsystem: subsystem, category: "spotifyService")

    nonisolated static let musicPlayer = Logger(subsystem: subsystem, category: "musicPlayer")

    nonisolated static let onboarding = Logger(subsystem: subsystem, category: "onboarding")
}
