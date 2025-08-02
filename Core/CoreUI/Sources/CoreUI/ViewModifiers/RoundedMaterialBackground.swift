//
//  RoundedMaterialBackground.swift
//  CoreUI
//
//  Created by Tomasz Wojtyniak on 02/08/2025.
//

import SwiftUI

public struct RoundedMaterialBackground: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .shadow(color: .backgroundColor, radius: 15, x: 0, y: 8)
            )
    }
}

public extension View {
    func roundedMaterialBackground() -> some View {
        modifier(RoundedMaterialBackground())
    }
}
