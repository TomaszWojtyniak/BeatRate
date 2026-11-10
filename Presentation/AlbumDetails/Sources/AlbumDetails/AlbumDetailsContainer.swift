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
import OSLog

/// Container view that fetches album data by ID before showing details
/// Checks cache first (home albums only), then fetches from MusicKit
public struct AlbumDetailsContainer: View {
    @State private var dataModel: AlbumDetailsContainerDataModel

    public init(
        albumId: String,
        getAlbumByIdUseCase: GetAlbumByIdUseCaseProtocol = GetAlbumByIdUseCase(),
        analyticsManager: AnalyticsManager = .shared
    ) {
        self._dataModel = State(initialValue: AlbumDetailsContainerDataModel(
            albumId: albumId,
            getAlbumByIdUseCase: getAlbumByIdUseCase,
            analyticsManager: analyticsManager
        ))
    }

    public var body: some View {
        Group {
            switch dataModel.state {
            case .loading:
                ProgressView(String(localized: .albumLoading))
            case .failed(let message):
                ContentUnavailableView {
                    Label(String(localized: .albumErrorTitle), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button(String(localized: .albumErrorRetry)) {
                        Task { await dataModel.retry() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .loaded(let album):
                AlbumDetailsView(album: album)
            }
        }
        .task {
            await dataModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        AlbumDetailsContainer(albumId: "1440935467")
    }
}
