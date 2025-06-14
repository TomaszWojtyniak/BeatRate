//
//  ErrorAlert.swift
//  CoreUI
//
//  Created by Tomasz Wojtyniak on 11/06/2025.
//

import SwiftUI

public struct ErrorAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String

    public func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button(String(localized: "error.alert.confirm", bundle: .module), role: .cancel) { }
            } message: {
                Text(message)
            }
    }
}

public extension View {
    func errorAlert(isPresented: Binding<Bool>, title: String, message: String) -> some View {
        self.modifier(ErrorAlertModifier(isPresented: isPresented, title: title, message: message))
    }
}
