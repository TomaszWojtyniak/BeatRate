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
          AnalyticsManager.shared.setAnalyticsEnabled(true)
          CrashLogger.shared.configure()
      }
      
    return true
  }
}
