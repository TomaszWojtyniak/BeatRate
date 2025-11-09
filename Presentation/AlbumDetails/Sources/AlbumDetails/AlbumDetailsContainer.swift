//
//  AlbumDetailsContainer.swift
//  AlbumDetails
//
//  Created by Claude on 25/10/2025.
//

import SwiftUI
import Models
import HomeUseCases

/// Container view that fetches album data by ID before showing details
/// Checks cache first (home albums only), then fetches from MusicKit
public struct AlbumDetailsContainer: View {
    let albumId: String

    @State private var albumModel: AlbumModel?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let getAlbumByIdUseCase: GetAlbumByIdUseCaseProtocol

    public init(
        albumId: String,
        getAlbumByIdUseCase: GetAlbumByIdUseCaseProtocol = GetAlbumByIdUseCase()
    ) {
        self.albumId = albumId
        self.getAlbumByIdUseCase = getAlbumByIdUseCase
    }

    public var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading album...")
            } else if let errorMessage = errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again") {
                        Task {
                            await fetchAlbum()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let albumModel = albumModel {
                AlbumDetailsView(album: albumModel)
            }
        }
        .task {
            await fetchAlbum()
        }
    }

    private func fetchAlbum() async {
        isLoading = true
        errorMessage = nil

        do {
            let album = try await getAlbumByIdUseCase.execute(albumId: albumId)
            albumModel = album
            isLoading = false
        } catch {
            errorMessage = "Failed to load album: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        AlbumDetailsContainer(albumId: "1440935467")
    }
}
