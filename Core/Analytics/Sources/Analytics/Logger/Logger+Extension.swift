//
//  Logger+Extension.swift
//  Analytics
//
//  Created by Tomasz Wojtyniak on 30/05/2025.
//

import OSLog

public extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier!

    static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")

    static let networking = Logger(subsystem: subsystem, category: "networking")
    
    static func `for`<T>(_ type: T.Type) -> Logger {
        return Logger(
            subsystem: subsystem,
            category: String(describing: type)
        )
    }
}
