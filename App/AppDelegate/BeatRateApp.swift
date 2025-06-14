//
//  BeatRateApp.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import SwiftData
import Models

@main
struct BeatRateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: User.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            AppView()
                .modelContainer(container)
        }
    }
}
