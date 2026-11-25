//
//  RootView.swift
//  AppRootUI
//

#if os(iOS)
import AppRoot
import CoreApp
import Login
import Onboarding
import SplashUI
import SwiftUI
import TabBar

/// The app's top level, as `AppNavigator` decides it: the splash, the player picker or
/// the tabs, with the consent alert and the login sheet over them.
public struct RootView: View {
    private let navigator: AppNavigator
    /// ponytail: the legacy tab bar's own selection; phase 3 moves tabs into Core.
    @State private var selection: TabBarScreen? = .home

    public init(navigator: AppNavigator) {
        self.navigator = navigator
    }

    public var body: some View {
        Group {
            switch navigator.state.phase {
            case .splash:
                SplashView(viewModel: navigator.splash)
                    .transition(.opacity)
            case .playerPicker:
                NavigationStack {
                    MusicPlayerPickerView(mode: .onboarding)
                }
            case .tabs:
                TabBarView(selection: $selection)
                    .onChange(of: selection) { _, tab in
                        if let tab { navigator.send(action: .selectedTab(String(describing: tab))) }
                    }
                    .alert(Text(.analyticsConsentTitle), isPresented: .constant(navigator.state.isAskingAnalyticsConsent)) {
                        Button(String(localized: .analyticsConsentDeny)) { navigator.send(action: .denyAnalytics) }
                        Button(String(localized: .analyticsConsentAllow)) { navigator.send(action: .allowAnalytics) }
                    } message: {
                        Text(.analyticsConsentMessage)
                    }
            }
        }
        .animation(.default, value: navigator.state.phase)
        // An item, not a flag: SwiftUI keeps the last reason while the sheet animates out.
        .sheet(item: Binding(
            get: { navigator.state.loginPrompt },
            set: { if $0 == nil { navigator.send(action: .dismissLoginPrompt) } }  // swiped down
        )) { reason in
            LoginPromptView(reason: reason)
                .presentationDragIndicator(.visible)
        }
    }
}
#endif
