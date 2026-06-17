//
//  ArtistDetailsDataModel.swift
//  ArtistDetails
//
//  Created by Tomasz Wojtyniak on 17/06/2026.
//

import Foundation
import Models
import ArtistUseCase
import Analytics
import OSLog

@MainActor
@Observable
final class ArtistDetailsDataModel {
    /// Where the artist is loaded from. Search has an artist ID; album details
    /// only knows the album, so the artist is resolved from it.
    enum Source {
        case albumId(String)
        case artistId(String)
    }

    private let source: Source
    private let getArtistDetailsUseCase: GetArtistDetailsUseCaseProtocol

    var artist: AppleMusicArtistData?
    var sections: [HomeSection] = []
    var isLoading = false
    var loadFailed = false

    private var loadTask: Task<Void, Never>?

    init(
        source: Source,
        getArtistDetailsUseCase: GetArtistDetailsUseCaseProtocol = GetArtistDetailsUseCase()
    ) {
        self.source = source
        self.getArtistDetailsUseCase = getArtistDetailsUseCase
    }

    func loadIfNeeded() {
        guard artist == nil, !isLoading else { return }
        loadTask = Task { await performLoad() }
    }

    private func performLoad() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            let artist: AppleMusicArtistData
            switch source {
            case .albumId(let id):
                artist = try await getArtistDetailsUseCase.fetchArtist(forAlbumId: id)
            case .artistId(let id):
                artist = try await getArtistDetailsUseCase.fetchArtist(byId: id)
            }
            self.artist = artist
            self.sections = Self.makeSections(from: artist)
        } catch {
            Logger.artistDetails.error("Failed to load artist: \(error)")
            loadFailed = true
        }
    }

    /// Builds the discography carousels, in display order, skipping empty groups.
    private static func makeSections(from artist: AppleMusicArtistData) -> [HomeSection] {
        var sections: [HomeSection] = []

        if let latest = artist.latestRelease {
            sections.append(HomeSection(sectionName: "Latest Release", albums: [albumModel(from: latest)]))
        }

        if let albums = artist.albums, !albums.isEmpty {
            sections.append(HomeSection(sectionName: "Albums", albums: albums.map(albumModel)))
        }

        if let singles = artist.singles, !singles.isEmpty {
            sections.append(HomeSection(sectionName: "Singles & EPs", albums: singles.map(albumModel)))
        }

        return sections
    }

    private static func albumModel(from data: AppleMusicAlbumData) -> AlbumModel {
        AlbumModel(id: data.id, appleMusicAlbumData: data, firebaseAlbumData: nil)
    }
}
