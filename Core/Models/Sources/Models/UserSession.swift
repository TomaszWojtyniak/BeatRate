//
//  UserSession.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 11/06/2025.
//

import SwiftData
import SwiftUI

@Model
public class UserSession {
    public var isLoggedIn: Bool
    public var userId: String

    
    public init(isLoggedIn: Bool = false, userId: String = "") {
        self.isLoggedIn = isLoggedIn
        self.userId = userId
    }
}
