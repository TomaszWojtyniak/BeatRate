//
//  SplashView.swift
//  Splash
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftUI
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
            Spacer()
            
            Image(systemName: "star.square.on.square")
                .resizable()
                .foregroundStyle(Color.honeyYellow)
                .frame(maxWidth: 200, maxHeight: 200)

            
            
            Text("login.app.name", bundle: .module)
                .font(.system(size: 70, weight: .medium))
                .foregroundStyle(Color.primaryText)
            
            Spacer()

            // Show retry status if retrying
            if dataModel.isRetrying {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text(dataModel.errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.primaryText)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 40)
        .background(Color.backgroundGradient)
        .task {
            await dataModel.loadInitialData()
            onComplete()
        }
        .errorAlert(isPresented: $dataModel.showError, title: "Connection Error", message: dataModel.errorMessage)
    }
}

#Preview {
    SplashView(onComplete: {})
}
