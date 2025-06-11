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

    
    public init(isLoggedIn: Bool = false) {
        self.isLoggedIn = isLoggedIn
    }
}
