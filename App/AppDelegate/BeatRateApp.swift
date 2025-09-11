//
//  BeatRateApp.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import SwiftData
import Models
import SwiftDataManager

@main
struct BeatRateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @State private var cacheManager = SwiftDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            AppView()
                .modelContainer(cacheManager.container)
                .environmentObject(cacheManager)
        }
    }
}
