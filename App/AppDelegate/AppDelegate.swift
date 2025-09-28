//
//  AppDelegate.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 28/05/2025.
//

import SwiftUI
import FirebaseCore
import Analytics
import FirebaseDatabase

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
      FirebaseApp.configure()
      Database.database().isPersistenceEnabled = true
      
      //Set cache size (10MB)
      Database.database().persistenceCacheSizeBytes = 10 * 1024 * 1024
      
      Task {
          AnalyticsManager.shared.setAnalyticsEnabled(true)
          CrashLogger.shared.configure()
      }
      
    return true
  }
}
