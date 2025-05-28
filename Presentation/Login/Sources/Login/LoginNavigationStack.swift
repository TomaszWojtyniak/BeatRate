//
//  LoginNavigationStack.swift
//  Login
//
//  Created by Tomasz Wojtyniak on 27/05/2025.
//

import SwiftUI

public struct LoginNavigationStack: View {
    
    public init() {
        
    }
    
    public var body: some View {
        NavigationStack {
            LoginView()
        }
    }
}

#Preview {
    LoginNavigationStack()
}
