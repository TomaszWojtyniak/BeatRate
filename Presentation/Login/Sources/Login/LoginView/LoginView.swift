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
import OSLog
import Models
import SwiftData

private let logger = Logger(subsystem: "BeatRate", category: "LoginView")

@MainActor
struct LoginView: View {
    @Environment(\.modelContext) private var context
    @Query private var userSession: [UserSession]
    
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
                        do {
                            let userId = try await self.dataModel.handleLoginFlow(authResult: authResult)
                            logger.debug("User login successful")
                            if let session = userSession.first {
                                logger.debug("User session model exist, changing values")
                                session.isLoggedIn = true
                                session.userId = userId
                            } else {
                                logger.debug("User session dont exist, creating a new one")
                                let newUserSession = UserSession(isLoggedIn: true, userId: userId)
                                context.insert(newUserSession)
                                logger.debug("New UserSession model created")
                            }
                        } catch let error {
                            await self.dataModel.handleLoginFailure(error: error)
                        }
                    case .failure(let error):
                        await self.dataModel.handleLoginFailure(error: error)
                    }
                }
            })
            .signInWithAppleButtonStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: 50)
            .padding()
                
        }
        .errorAlert(isPresented: $dataModel.isShowingErrorAlert,
                    title: String(localized: "login.alert.error.title", bundle: .module),
                    message: String(localized: "login.alert.error.description", bundle: .module))
        .padding(.horizontal)
        .padding(.vertical, 40)
        .background(Color.backgroundGradient)
    }
}

#Preview {
    LoginView()
}
