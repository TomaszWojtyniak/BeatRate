//
//  AccountGuestView.swift
//  Account
//

import SwiftUI
import CoreUI
import Analytics
import Settings

struct AccountGuestView: View {
    let dataModel: AccountGuestDataModel
    @State private var showingSettings = false

    private let benefits: [(icon: String, title: String, detail: String)] = [
        ("star.fill",
         String(localized: .guestFeatureRatingsTitle),
         String(localized: .guestFeatureRatingsMessage)),
        ("square.grid.2x2.fill",
         String(localized: .guestFeatureLibraryTitle),
         String(localized: .guestFeatureLibraryMessage)),
        ("music.pages.fill",
         String(localized: .guestFeatureConnectTitle),
         String(localized: .guestFeatureConnectMessage))
    ]

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Size.avatar, height: Size.avatar)
                    .foregroundStyle(Color.accentPrimary)
                    .appShadow(.accentGlow)

                Text(.guestTitle)
                    .textStyle(.titleSection)
                    .padding(.top, Spacing.xs)

                Text(.guestMessage)
                    .textStyle(.body, color: .secondaryText)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Spacing.md) {
                ForEach(benefits, id: \.title) { benefit in
                    benefitRow(benefit)
                }
            }
            .padding(Spacing.lg)
            .roundedMaterialBackground()

            Button {
                dataModel.requestLogin()
            } label: {
                Text(.guestSignIn)
                    .textStyle(.bodyEmphasis, color: .primaryTextOnDark)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.xs)
                    .background(Capsule().fill(Color.accentPrimaryGradient))
                    .appShadow(.accentGlow)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .meshBackground()
        .navigationTitle(String(localized: .accountNavigationTitle))
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem {
                Button(String(localized: .accountSettings), systemImage: "gear") {
                    showingSettings = true
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            dataModel.autoPromptIfNeeded()
        }
        .onAppear { dataModel.track(.screenView(.accountGuest)) }
    }

    private func benefitRow(_ benefit: (icon: String, title: String, detail: String)) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: benefit.icon)
                .textStyle(.iconAction, color: .accentPrimary)
                .frame(width: Size.touchTarget, height: Size.touchTarget)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(benefit.title)
                    .textStyle(.bodyEmphasis)
                Text(benefit.detail)
                    .textStyle(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        AccountGuestView(dataModel: AccountGuestDataModel())
    }
}
