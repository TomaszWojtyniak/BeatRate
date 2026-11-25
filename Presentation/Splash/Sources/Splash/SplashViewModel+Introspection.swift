//
//  SplashViewModel+Introspection.swift
//  Splash
//

import IntrospectionKit

extension SplashViewModel: IntrospectionProviding {
    public var introspectionNode: any IntrospectionNode { Node(viewModel: self) }

    /// `MusicExplainer` while the explainer covers the splash, `Splash` otherwise.
    /// `Continue` is always listed; `update` ignores it outside the explainer.
    private struct Node: IntrospectionNode {
        let viewModel: SplashViewModel
        var name: String { viewModel.state.phase == .musicExplainer ? "MusicExplainer" : "Splash" }
        var state: any Encodable { viewModel.state }
        var actions: [IntrospectionAction] {
            [IntrospectionAction("Continue") { viewModel.send(action: .continuePastExplainer) }]
        }
    }
}
