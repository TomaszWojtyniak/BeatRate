//
//  AppDelegate.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 28/05/2025.
//

import Analytics
import SwiftUI

/// Runs after `BeatRateMain.init` has configured Firebase and built the root.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        CrashLogger.shared.configure()
        return true
    }
}
