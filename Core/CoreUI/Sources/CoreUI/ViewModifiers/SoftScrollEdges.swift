//
//  SoftScrollEdges.swift
//  CoreUI
//
//  Created by Claude on 05/10/2026.
//

import SwiftUI

public extension View {
    /// Soft Liquid Glass scroll edge effect on every edge — the treatment every
    /// full-page scroll view shares, so bars and content fade into each other.
    func softScrollEdges() -> some View {
        scrollEdgeEffectStyle(.soft, for: .all)
    }
}
