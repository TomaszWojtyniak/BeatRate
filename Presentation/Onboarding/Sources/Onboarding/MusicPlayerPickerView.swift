//
//  MusicPlayerPickerView.swift
//  Onboarding
//

import SwiftUI
import Models
import CoreUI
import CoreApp

public struct MusicPlayerPickerView: View {
    @State private var dataModel: MusicPlayerPickerDataModel
    @Environment(\.dismiss) private var dismiss
    private let musicPlayerManager = MusicPlayerManager.shared

    private let onComplete: (() -> Void)?

    public init(mode: MusicPlayerPickerMode, onComplete: (() -> Void)? = nil) {
        self._dataModel = State(initialValue: MusicPlayerPickerDataModel(mode: mode))
        self.onComplete = onComplete
    }

    private var isOnboarding: Bool { dataModel.mode == .onboarding }

    public var body: some View {
        ZStack {
            OnboardingPickerBackground(isOnboarding: isOnboarding)

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    OnboardingPickerHeader(isOnboarding: isOnboarding)

                    GlassEffectContainer(spacing: Spacing.md) {
                        VStack(spacing: Spacing.md) {
                            ForEach(MusicPlayer.allCases, id: \.self) { player in
                                OnboardingPlayerCard(
                                    player: player,
                                    isOnboarding: isOnboarding,
                                    isSelected: musicPlayerManager.current == player,
                                    isPending: dataModel.pendingChoice == player,
                                    isDisabled: dataModel.isProcessing,
                                    onTap: { handleSelection(of: player) }
                                )
                            }
                        }
                    }

                    if let message = dataModel.errorMessage {
                        Text(message)
                            .textStyle(.caption, color: Color.errorRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)
                    }

                    Spacer(minLength: Spacing.xl)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(isOnboarding ? .dark : nil, for: .navigationBar)
        .toolbar(dataModel.mode == .change ? .visible : .hidden, for: .navigationBar)
        .navigationTitle(dataModel.mode == .change ? "Main music player" : "")
        .toolbarTitleDisplayMode(.inline)
    }

    private func handleSelection(of player: MusicPlayer) {
        Task {
            let didComplete = await dataModel.select(player)
            guard didComplete else { return }
            if dataModel.mode == .change {
                dismiss()
            } else {
                onComplete?()
            }
        }
    }
}

#Preview {
    NavigationStack {
        MusicPlayerPickerView(mode: .onboarding)
    }
}
