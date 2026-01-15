//
//  Logger+Extension.swift
//  Analytics
//
//  Created by Tomasz Wojtyniak on 30/05/2025.
//

import OSLog

public extension Logger {
    private static let subsystem = "BeatRate"
    
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
    
    static let crashLogger = Logger(subsystem: subsystem, category: "crashLogger")
    
    static let homeRepository = Logger(subsystem: subsystem, category: "homeRepository")
    
    static let musicRepository = Logger(subsystem: subsystem, category: "musicRepository")

    static let musicService = Logger(subsystem: subsystem, category: "musicKit")

    static let loginRepository = Logger(subsystem: subsystem, category: "loginRepository")

    static let loginUseCases = Logger(subsystem: subsystem, category: "loginUseCases")

    static let firebaseService = Logger(subsystem: subsystem, category: "firebaseService")
    
    static let home = Logger(subsystem: subsystem, category: "home")
    
    static let login = Logger(subsystem: subsystem, category: "login")
    
    static let app = Logger(subsystem: subsystem, category: "app")
    
    static let splash = Logger(subsystem: subsystem, category: "splash")

    static let albumDetails = Logger(subsystem: subsystem, category: "albumDetails")

    static let account = Logger(subsystem: subsystem, category: "account")

    static let accountRepository = Logger(subsystem: subsystem, category: "accountRepository")

    static let settings = Logger(subsystem: subsystem, category: "settings")

    static let swiftDataManager = Logger(subsystem: subsystem, category: "swiftDataManager")
}
