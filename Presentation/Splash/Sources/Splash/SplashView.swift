//
//  SplashView.swift
//  Splash
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftUI
import Models
import HomeRepository
import MusicRepository
import CoreUI

@MainActor
public struct SplashView: View {
    
    @State private var dataModel: SplashDataModel = SplashDataModel()
    
    let onComplete: () -> Void
    
    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack {
            Text("Splash view")
        }
        .task {
            await dataModel.loadInitialData()
            onComplete()
        }
        .alert("Error", isPresented: $dataModel.showError) {
            
        }
    }
}
