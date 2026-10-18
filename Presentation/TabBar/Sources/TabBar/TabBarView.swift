//
//  AppTabView.swift
//  TabBar
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import MusicKit
import CoreUI
import Analytics


@MainActor
public struct TabBarView: View {
    @Binding var selection: TabBarScreen?
    let tabs: [TabBarScreen] = TabBarScreen.allCases
    @Environment(\.scenePhase) private var scenePhase
    /// Home and Search are built on Apple Music catalog data. Account stays open
    /// so logout and account deletion are always reachable (App Review 5.1.1(v)).
    /// Re-read on each return to the foreground: access is granted in Settings.
    @State private var hasMusicAccess = MusicAuthorization.currentStatus == .authorized

    public init(selection: Binding<TabBarScreen?>) {
        self._selection = selection
    }
    
    public var body: some View {
        TabView(selection: $selection) {
            ForEach(tabs) { tab in
                Tab(value: tab, role: tab == TabBarScreen.search ? .prominent : .none) {
                    if hasMusicAccess || tab == .account {
                        tab.destination
                    } else {
                        MusicAccessUnavailableView()
                    }
                } label: {
                    tab.label
                }
            }
        }
        .tint(Color.accentPrimary)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            hasMusicAccess = MusicAuthorization.currentStatus == .authorized
        }
    }
}

private struct MusicAccessUnavailableView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label(String(localized: .musicAccessTitle), systemImage: "music.note")
                .foregroundStyle(Color.primaryText)
        } description: {
            Text(.musicAccessMessage)
                .textStyle(.body, color: .secondaryText)
        } actions: {
            Button(String(localized: .musicAccessOpenSettings)) {
                AnalyticsManager.shared.log(.openSystemSettingsTap)
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .meshBackground()
    }
}

#Preview {
    TabBarView(selection: .constant(.home))
}
