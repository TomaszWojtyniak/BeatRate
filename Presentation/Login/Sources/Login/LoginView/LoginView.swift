//
//  LoginView.swift
//  Login
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI

@MainActor
struct LoginView: View {
    
    @State private var dataModel: LoginDataModel = LoginDataModel()
    
    var body: some View {
        Text("Hello, World!")
    }
}

#Preview {
    LoginView()
}
