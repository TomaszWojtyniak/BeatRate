//
//  AccountNavigationStack.swift
//  Account
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI

public struct AccountNavigationStack: View {
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            AccountView()
        }
    }
}

#Preview {
    AccountNavigationStack()
}
