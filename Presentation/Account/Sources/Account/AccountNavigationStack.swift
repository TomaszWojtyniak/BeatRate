//
//  AccountNavigationStack.swift
//  Account
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI

public struct AccountNavigationStack: View {

    @State private var dataModel = AccountGuestDataModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            if dataModel.isLoggedIn {
                AccountView()
            } else {
                AccountGuestView(dataModel: dataModel)
            }
        }
    }
}

#Preview {
    AccountNavigationStack()
}
