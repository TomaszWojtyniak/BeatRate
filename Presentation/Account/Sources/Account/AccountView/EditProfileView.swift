//
//  EditProfileView.swift
//  Account
//
//  Created by Tomasz Wojtyniak on 09/01/2026.
//

import SwiftUI
import CoreUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field { case first, last }

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

    private var canSave: Bool {
        !isSaving && !(firstName.isEmpty && lastName.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .first)
                        .onSubmit { focusedField = .last }

                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($focusedField, equals: .last)
                        .onSubmit { if canSave { save() } }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .disabled(isSaving)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        Task {
            isSaving = true
            await onSave(firstName, lastName)
            isSaving = false
            dismiss()
        }
    }
}
