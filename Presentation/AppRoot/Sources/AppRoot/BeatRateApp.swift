//
//  BeatRateApp.swift
//  AppRoot
//

import Composition
import IntrospectionKit

/// The root of the app's object tree. The iOS app and the CLI are two hosts that build
/// it; they differ only in the edges they pass.
public final class BeatRateApp: IntrospectionProviding {
    public let graph: Graph
    public let navigator: AppNavigator

    public init(edges: Edges) {
        graph = Graph(edges: edges)   // installs the crash backend first, then builds every object once
        Graph.current = graph         // ponytail: only for legacy DataModels; phase 6 removes it
        navigator = AppNavigator(graph: graph)
    }

    // ponytail: the root lends nothing yet, so its node is the navigator's (as in the reference).
    public var introspectionNode: any IntrospectionNode { navigator.introspectionNode }
}
