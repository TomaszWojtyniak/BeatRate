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
            // Only proceed if there are no critical errors
            if dataModel.shouldComplete {
                onComplete()
            }
            // If shouldComplete is false, we stay on splash screen with error alert
        }
        .alert(
            dataModel.alertType == .connectionError ? "Connection Error" : "Apple Music Access Required",
            isPresented: Binding(
                get: { dataModel.alertType != nil },
                set: { if !$0 { dataModel.alertType = nil } }
            )
        ) {
            if dataModel.alertType == .musicKitDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Try Again") {
                    Task {
                        await dataModel.retryAfterSettingsChange()
                        if dataModel.shouldComplete {
                            onComplete()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    Task {
                        await dataModel.logout()
                        onComplete()
                    }
                }
            } else {
                // Connection error - offer retry
                Button("Retry") {
                    Task {
                        await dataModel.retryAfterSettingsChange()
                        if dataModel.shouldComplete {
                            onComplete()
                        }
                    }
                }
                Button("Logout", role: .destructive) {
                    Task {
                        await dataModel.logout()
                        onComplete()
                    }
                }
                Button("Cancel", role: .cancel) {
                    // Stay on splash screen with error showing
                }
            }
        } message: {
            Text(dataModel.errorMessage)
        }
    }
}

#Preview {
    SplashView(onComplete: {})
}
