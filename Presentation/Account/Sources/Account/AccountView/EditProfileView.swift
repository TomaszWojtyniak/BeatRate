//
//  EditProfileView.swift
//  Account
//
//  Created by Tomasz Wojtyniak on 09/01/2026.
//

import SwiftUI
import Models
import CoreUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var favorites: [AlbumModel]
    @State private var showingFavoritesManager = false
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field { case first, last }

    let currentFirstName: String?
    let currentLastName: String?
    let onSave: (String, String) async -> Void
    let onSaveFavorites: ([AlbumModel]) async -> Void

    init(firstName: String?,
         lastName: String?,
         favorites: [AlbumModel],
         onSave: @escaping (String, String) async -> Void,
         onSaveFavorites: @escaping ([AlbumModel]) async -> Void) {
        self.currentFirstName = firstName
        self.currentLastName = lastName
        self._firstName = State(initialValue: firstName ?? "")
        self._lastName = State(initialValue: lastName ?? "")
        self._favorites = State(initialValue: favorites)
        self.onSave = onSave
        self.onSaveFavorites = onSaveFavorites
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

                Section("Favorites") {
                    Button {
                        showingFavoritesManager = true
                    } label: {
                        HStack {
                            Text("Edit favorites")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text("\(favorites.count)/\(AccountDataModel.maxFavorites)")
                                .foregroundStyle(.primary)
                            
                            Image(systemName: "chevron.right")
                                .textStyle(.iconRowAccessory, foreground: .tertiary)
                        }
                    }
                    .disabled(isSaving)
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
        .sheet(isPresented: $showingFavoritesManager) {
            FavoritesManagerView(initial: favorites) { updated in
                favorites = updated
                await onSaveFavorites(updated)
            }
        }
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
