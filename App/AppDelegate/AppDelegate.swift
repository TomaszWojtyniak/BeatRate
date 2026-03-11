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
import CoreApp

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        let database = Database.database(url: AppEnvironment.current.firebaseDatabaseUrl)
        database.isPersistenceEnabled = true
        
        // Set cache size (10MB)
        database.persistenceCacheSizeBytes = 10 * 1024 * 1024
        
        Task {
            AnalyticsManager.shared.setAnalyticsEnabled(true)
            CrashLogger.shared.configure()
        }
        
        return true
    }
}
