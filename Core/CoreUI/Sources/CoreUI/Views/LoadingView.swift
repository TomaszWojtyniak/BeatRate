//
//  LoadingView.swift
//  CoreUI
//
//  Created by Tomasz Wojtyniak on 08/10/2025.
//

import SwiftUI

public struct LoadingView<Content: View>: View {
    let isLoading: Bool
    let message: String?
    let content: Content

    public init(
        isLoading: Bool,
        message: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.message = message
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content
                .blur(radius: isLoading ? 2 : 0)
                .disabled(isLoading)
                .animation(.easeInOut(duration: 0.2), value: isLoading)

            // Activity indicator overlay (HIG compliant)
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                        .scaleEffect(1.3)

                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 28)
                .glassEffect()
            }
        }
    }
}

// MARK: - View Extension
public extension View {
    func loading(
        _ isLoading: Bool,
        message: String? = nil
    ) -> some View {
        LoadingView(isLoading: isLoading, message: message) {
            self
        }
    }
}

#Preview {
    VStack {
        LoadingView(isLoading: true, message: "Saving...") {
            VStack(spacing: 20) {
                Text("Sample Content")
                    .font(.title)
                Button("Action") {}
                    .buttonStyle(.borderedProminent)
            }
            .padding(40)
            .background(Color.gray.opacity(0.2))
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
