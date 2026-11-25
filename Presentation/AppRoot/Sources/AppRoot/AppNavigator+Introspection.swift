//
//  AppNavigator+Introspection.swift
//  AppRoot
//

import CoreApp
import IntrospectionKit

extension AppNavigator: IntrospectionProviding {
    public var introspectionNode: any IntrospectionNode { Node(navigator: self) }

    /// The app's top level. Below it: the login sheet while it is up, else the consent
    /// alert while it covers the tabs, else the splash, the player picker or the tabs.
    private struct Node: IntrospectionNode {
        let navigator: AppNavigator
        var name: String { "App" }
        var state: any Encodable { navigator.state }
        var actions: [IntrospectionAction] { [] }
        var child: (any IntrospectionNode)? {
            let state = navigator.state
            if let reason = state.loginPrompt { return LoginPrompt(navigator: navigator, reason: reason) }
            if state.phase == .tabs && state.isAskingAnalyticsConsent { return AnalyticsConsent(navigator: navigator) }
            switch state.phase {
            case .splash: return navigator.splash.introspectionNode
            case .playerPicker: return Leaf(name: "PlayerPicker", navigator: navigator)
            case .tabs: return Leaf(name: "Tabs", navigator: navigator)
            }
        }
    }

    /// The legacy login sheet; lends `dismiss`, so it exists only while the sheet is up.
    private struct LoginPrompt: IntrospectionNode {
        let navigator: AppNavigator
        let reason: LoginPromptReason
        var name: String { "LoginPrompt" }
        var state: any Encodable { ["reason": reason.rawValue] }
        var actions: [IntrospectionAction] {
            [IntrospectionAction("dismiss") { navigator.send(action: .dismissLoginPrompt) }]
        }
    }

    private struct AnalyticsConsent: IntrospectionNode {
        let navigator: AppNavigator
        var name: String { "AnalyticsConsent" }
        var state: any Encodable { [String: String]() }
        var actions: [IntrospectionAction] {
            [
                IntrospectionAction("AllowAnalytics") { navigator.send(action: .allowAnalytics) },
                IntrospectionAction("DenyAnalytics") { navigator.send(action: .denyAnalytics) },
            ]
        }
    }
}

/// A screen still built the old way (phases 3–5 move it into Core): seen, not driven.
/// It has no state of its own, so it shows the app's — login, consent, player — which
/// is what a journey that ends on it wants to check.
private struct Leaf: IntrospectionNode {
    let name: String
    let navigator: AppNavigator
    var state: any Encodable { navigator.state }
    var actions: [IntrospectionAction] { [] }
}
