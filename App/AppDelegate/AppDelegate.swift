//
//  AppDelegate.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 28/05/2025.
//

import SwiftUI
import FirebaseCore
import Analytics

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
      FirebaseApp.configure()
      
      Task {
          if let bundleID = Bundle.main.bundleIdentifier, bundleID == "tomasz.wojtyniak.beat.rate" {
              await AnalyticsManager.shared.configure(debugMode: false)
              await CrashLogger.shared.configure(minimumLogLevel: .notice,
                                                 debugMode: false,
                                                 crashlyticsEnabled: true)
          } else {
              await AnalyticsManager.shared.configure(debugMode: true)
              await CrashLogger.shared.configure(minimumLogLevel: .debug,
                                                 debugMode: true,
                                                 crashlyticsEnabled: true)
          }
      }
      
    return true
  }
}
