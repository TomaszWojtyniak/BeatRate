//
//  AlbumDetailsContainer.swift
//  AlbumDetails
//
//  Created by Claude on 25/10/2025.
//

import SwiftUI
import Models
import HomeUseCases
import Analytics

/// Container view that fetches album data by ID before showing details
/// Checks cache first (home albums only), then fetches from MusicKit
public struct AlbumDetailsContainer: View {
    let albumId: String

    private enum LoadState {
        case loading
        case loaded(AlbumModel)
        case failed(String)
    }

    @State private var state: LoadState = .loading

    private let getAlbumByIdUseCase: GetAlbumByIdUseCaseProtocol
    private let analyticsManager: AnalyticsManager

    public init(
        albumId: String,
        getAlbumByIdUseCase: GetAlbumByIdUseCaseProtocol = GetAlbumByIdUseCase(),
        analyticsManager: AnalyticsManager = .shared
    ) {
        self.albumId = albumId
        self.getAlbumByIdUseCase = getAlbumByIdUseCase
        self.analyticsManager = analyticsManager
    }

    public var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Loading album...")
            case .failed(let message):
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") {
                        analyticsManager.log(.retryTap(screen: .albumDetails))
                        Task { await fetchAlbum() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .loaded(let album):
                AlbumDetailsView(album: album)
            }
        }
        .task {
            await fetchAlbum()
        }
    }

    private func fetchAlbum() async {
        state = .loading
        do {
            let album = try await getAlbumByIdUseCase.fetchAlbum(id: albumId)
            state = .loaded(album)
        } catch {
            state = .failed("Failed to load album: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        AlbumDetailsContainer(albumId: "1440935467")
    }
}
