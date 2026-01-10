//
//  AccountView.swift
//  Account
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Settings
import Models
import AlbumDetails
import CoreUI

public struct AccountView: View {

    @State private var showingSettings = false
    @State private var dataModel = AccountDataModel()
    @State private var selectedAlbum: AlbumModel?

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if !dataModel.isLoading {
                    VStack(spacing: 8) {
                        Text((dataModel.fullName ?? dataModel.userProfile?.email) ?? "")
                            .font(.system(.largeTitle, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Button("Edit") {
                            dataModel.isShowingEditSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                    HomeSectionView(name: "Ratings", albums: dataModel.ratedAlbums, selectedAlbum: $selectedAlbum)
                        .padding(20)
                        .roundedMaterialBackground()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.top, 5)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(Color.backgroundColor)
            .background(Color.backgroundColor)
            .loading(dataModel.isLoading)
        }
        .navigationDestination(item: $selectedAlbum) { album in
            AlbumDetailsNavigationStack(album: album)
        }
        .navigationTitle("Account")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem {
                Button("Settings", systemImage: "gear") {
                    showingSettings = true
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $dataModel.isShowingEditSheet) {
            EditProfileView(
                firstName: dataModel.userProfile?.firstName,
                lastName: dataModel.userProfile?.lastName
            ) { firstName, lastName in
                await dataModel.saveUserProfile(firstName: firstName, lastName: lastName)
            }
        }
        .task {
            await dataModel.loadUserData()
        }
    }
}

#Preview {
    AccountView()
}
