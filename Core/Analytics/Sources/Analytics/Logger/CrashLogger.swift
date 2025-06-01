//
//  CrashLogger.swift
//  Analytics
//
//  Created by Tomasz Wojtyniak on 28/05/2025.
//

import Foundation
import OSLog
import FirebaseCrashlytics

// MARK: - Log Level
public enum LogLevel: Int, CaseIterable, Comparable {
    case debug = 0
    case info = 1
    case notice = 2
    case warning = 3
    case error = 4
    case fault = 5
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .notice: return .default
        case .warning: return .error
        case .error: return .error
        case .fault: return .fault
        }
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .notice: return "📋"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .fault: return "💥"
        }
    }
    
    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .notice: return "NOTICE"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .fault: return "FAULT"
        }
    }
}

// MARK: - Log Context
public struct LogContext: Sendable {
    let file: String
    let function: String
    let line: Int
    let userInfo: [String: String]?
    
    public init(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        userInfo: [String: String]? = nil
    ) {
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
        self.userInfo = userInfo
    }
    
    var locationString: String {
        return "\(file):\(function):\(line)"
    }
}

@globalActor
public actor CrashLogger {
    public static let shared = CrashLogger()
    
    private let logger: Logger
    private let subsystem: String
    private let category: String
    private var minimumLogLevel: LogLevel = .debug
    private var isDebugMode: Bool = false
    private var isCrashlyticsEnabled: Bool = true
    
    // Breadcrumb tracking for crash context
    private var breadcrumbs: [String] = []
    private let maxBreadcrumbs = 50
    
    private init() {
        self.subsystem = Bundle.main.bundleIdentifier ?? "tomasz.wojtyniak.beat.rate"
        self.category = "CrashLogger"
        self.logger = Logger(subsystem: subsystem, category: category)
        
        logger.info("CrashLogger initialized")
    }
    
    public func configure(
        minimumLogLevel: LogLevel = .debug,
        debugMode: Bool = false,
        crashlyticsEnabled: Bool = true
    ) {
        self.minimumLogLevel = minimumLogLevel
        self.isDebugMode = debugMode
        self.isCrashlyticsEnabled = crashlyticsEnabled
        
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(crashlyticsEnabled)
        
        logger.info("CrashLogger configured - MinLevel: \(minimumLogLevel.description), Debug: \(debugMode), Crashlytics: \(crashlyticsEnabled)")
    }

    func log(
        level: LogLevel,
        message: String,
        error: Error? = nil,
        context: LogContext = LogContext(),
        reportToCrashlytics: Bool = true
    ) {
        guard level >= minimumLogLevel else { return }
        
        let formattedMessage = formatMessage(message, level: level, context: context, error: error)
        
        // Log to Swift Logger
        logger.log(level: level.osLogType, "\(formattedMessage)")
        
        // Add breadcrumb for crash context
        addBreadcrumb("\(level.description): \(message)")
        
        // Report to Crashlytics if enabled
        if isCrashlyticsEnabled && reportToCrashlytics {
            self.reportToCrashlytics(level: level, message: message, error: error, context: context)
        }
        
        // Print to console in debug mode
        if isDebugMode {
            print("\(level.emoji) [\(level.description)] \(formattedMessage)")
        }
    }
    
    public func debug(
        _ message: String,
        context: LogContext = LogContext()
    ) {
        log(level: .debug, message: message, context: context, reportToCrashlytics: false)
    }
    
    public func info(
        _ message: String,
        context: LogContext = LogContext()
    ) {
        log(level: .info, message: message, context: context, reportToCrashlytics: false)
    }
    
    public func notice(
        _ message: String,
        context: LogContext = LogContext()
    ) {
        log(level: .notice, message: message, context: context)
    }
    
    public func warning(
        _ message: String,
        error: Error? = nil,
        context: LogContext = LogContext()
    ) {
        log(level: .warning, message: message, error: error, context: context)
    }
    
    public func error(
        _ message: String,
        error: Error? = nil,
        context: LogContext = LogContext()
    ) {
        log(level: .error, message: message, error: error, context: context)
    }
    
    public func fault(
        _ message: String,
        error: Error? = nil,
        context: LogContext = LogContext()
    ) {
        log(level: .fault, message: message, error: error, context: context)
    }
    
    public func recordError(
        _ error: Error,
        message: String? = nil,
        context: LogContext = LogContext(),
        userInfo: [String: Any]? = nil
    ) {
        let errorMessage = message ?? "Recorded Error: \(error.localizedDescription)"
        
        log(level: .error, message: errorMessage, error: error, context: context)
        
        if isCrashlyticsEnabled {
            // Set custom keys for additional context
            if let userInfo = userInfo {
                for (key, value) in userInfo {
                    Crashlytics.crashlytics().setCustomValue(value, forKey: key)
                }
            }
            
            // Record the error
            Crashlytics.crashlytics().record(error: error)
        }
    }
    
    public func setUserIdentifier(_ identifier: String) {
        if isCrashlyticsEnabled {
            Crashlytics.crashlytics().setUserID(identifier)
        }
        info("User identifier set: \(identifier)")
    }
    
    private func addBreadcrumb(_ breadcrumb: String) {
        let timestamp = DateFormatter.breadcrumbFormatter.string(from: Date())
        let formattedBreadcrumb = "[\(timestamp)] \(breadcrumb)"
        
        breadcrumbs.append(formattedBreadcrumb)
        
        // Keep only the last N breadcrumbs
        if breadcrumbs.count > maxBreadcrumbs {
            breadcrumbs.removeFirst()
        }
        
        // Log breadcrumb to Crashlytics
        if isCrashlyticsEnabled {
            Crashlytics.crashlytics().log(formattedBreadcrumb)
        }
    }
    
    func logBreadcrumb(_ message: String) {
        addBreadcrumb("BREADCRUMB: \(message)")
    }
    
    private func formatMessage(
        _ message: String,
        level: LogLevel,
        context: LogContext,
        error: Error?
    ) -> String {
        var components: [String] = []
        
        // Add location info
        components.append("[\(context.locationString)]")
        
        // Add main message
        components.append(message)
        
        // Add error info if present
        if let error = error {
            components.append("Error: \(error.localizedDescription)")
            
            // Add additional error details for higher severity
            if level >= .error {
                let nsError = error as NSError
                components.append("Domain: \(nsError.domain), Code: \(nsError.code)")
                
                if !nsError.userInfo.isEmpty {
                    components.append("UserInfo: \(nsError.userInfo)")
                }
            }
        }
        
        // Add user info from context
        if let userInfo = context.userInfo, !userInfo.isEmpty {
            components.append("Context: \(userInfo)")
        }
        
        return components.joined(separator: " | ")
    }
    
    private func reportToCrashlytics(
        level: LogLevel,
        message: String,
        error: Error?,
        context: LogContext
    ) {
        guard level >= .notice else { return }
        
        let crashlytics = Crashlytics.crashlytics()
        
        // Set custom keys for context
        crashlytics.setCustomValue(level.description, forKey: "log_level")
        crashlytics.setCustomValue(context.locationString, forKey: "log_location")
        
        if let userInfo = context.userInfo {
            for (key, value) in userInfo {
                crashlytics.setCustomValue(value, forKey: "context_\(key)")
            }
        }
        
        // Log message
        crashlytics.log("\(level.description): \(message)")
        
        // Record error if present and severe enough
        if let error = error, level >= .error {
            crashlytics.record(error: error)
        }
    }
}

extension DateFormatter {
    static let breadcrumbFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
