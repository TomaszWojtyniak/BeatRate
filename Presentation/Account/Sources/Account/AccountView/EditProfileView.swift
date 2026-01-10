//
//  EditProfileView.swift
//  Account
//
//  Created by Tomasz Wojtyniak on 09/01/2026.
//

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var isSaving = false

    let currentFirstName: String?
    let currentLastName: String?
    let onSave: (String, String) async -> Void

    init(firstName: String?, lastName: String?, onSave: @escaping (String, String) async -> Void) {
        self.currentFirstName = firstName
        self.currentLastName = lastName
        self._firstName = State(initialValue: firstName ?? "")
        self._lastName = State(initialValue: lastName ?? "")
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                        .autocorrectionDisabled()

                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            await onSave(firstName, lastName)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving || (firstName.isEmpty && lastName.isEmpty))
                }
            }
            .disabled(isSaving)
        }
    }
}
