//
//  LoginView.swift
//  Login
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import Analytics
import CoreUI
import AuthenticationServices

@MainActor
struct LoginView: View {
    
    @State private var dataModel: LoginDataModel = LoginDataModel()
    
    var body: some View {
        VStack {
            Spacer()
            
            Image(systemName: "star.square.on.square")
                .resizable()
                .foregroundStyle(Color.honeyYellow)
                .frame(maxWidth: 200, maxHeight: 200)

            
            
            Text("login.app.name", bundle: .module)
                .font(.system(size: 70, weight: .medium))
                .foregroundStyle(Color.primaryText)
            
            Spacer()
            
            SignInWithAppleButton(onRequest: { request in
                Task {
                    let nonce = await self.dataModel.getCurrentNonce()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = self.dataModel.sha256(nonce)
                }
            }, onCompletion: { result in
                Task {
                    switch result {
                    case .success(let authResult):
                        try await self.dataModel.handleLoginSuccess(authResult: authResult)
                    case .failure(let error):
                        self.dataModel.handleLoginFailure(error: error)
                    }
                }
            })
            .signInWithAppleButtonStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: 50)
            .padding()
                
        }
        .padding(.horizontal)
        .padding(.vertical, 40)
        .background(Color.backgroundGradient)
    }
}

#Preview {
    LoginView()
}
