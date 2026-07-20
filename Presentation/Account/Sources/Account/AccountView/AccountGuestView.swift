//
//  AccountGuestView.swift
//  Account
//

import SwiftUI
import CoreUI

/// What a guest sees in place of the Account tab: a short pitch for what an
/// account unlocks, plus the CTA that raises the sign-in sheet.
///
/// The sheet itself lives on `AppView` — this only asks the data model to open it,
/// which keeps the Account package free of a dependency on Login.
struct AccountGuestView: View {
    let dataModel: AccountGuestDataModel

    private let benefits: [(icon: String, title: String, detail: String)] = [
        ("star.fill", "Your ratings", "Score albums on a ten-point scale and keep the record."),
        ("square.grid.2x2.fill", "Your library", "Everything you've rated, in one place."),
        ("music.pages.fill", "Connect your music library", "See your recently listened albums and more.")
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

                Text("Keep your ratings")
                    .textStyle(.titleSection)
                    .padding(.top, Spacing.xs)

                Text("You're browsing as a guest. Create an account to start rating.")
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
                Text("Sign in or create account")
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
        .navigationTitle("Account")
        .toolbarTitleDisplayMode(.inlineLarge)
        .onAppear {
            dataModel.autoPromptIfNeeded()
        }
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
