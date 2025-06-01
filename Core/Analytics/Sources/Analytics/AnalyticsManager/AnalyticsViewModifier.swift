//
//  AnalyticsViewModifier.swift
//  Analytics
//
//  Created by Tomasz Wojtyniak on 28/05/2025.
//

import SwiftUI

struct AnalyticsViewModifier: ViewModifier {
    let screenName: String
    let screenClass: String?
    
    init(screenName: String, screenClass: String? = nil) {
        self.screenName = screenName
        self.screenClass = screenClass
    }
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                Task {
                    await AnalyticsManager.shared.trackScreenView(screenName, screenClass: screenClass)
                }
            }
    }
}
