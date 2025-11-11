//
//  FirebaseUserProfile.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 11/11/2025.
//

import Foundation

public struct FirebaseUserProfile: Codable, Sendable {
    public let email: String?
    public let firstName: String?
    public let lastName: String?

    public init(email: String?,
                firstName: String?,
                lastName: String?) {
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
    }
}
