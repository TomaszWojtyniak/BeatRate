//
//  LoginView.swift
//  Login
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import Analytics

@MainActor
struct LoginView: View {
    
    @State private var dataModel: LoginDataModel = LoginDataModel()
    
    var body: some View {
        VStack {
            Text("Login screen")
        }
        .trackScreenView("LoginView", screenClass: "Login")
    }
}

#Preview {
    LoginView()
}
