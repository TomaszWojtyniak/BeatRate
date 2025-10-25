//
//  SearchDataModel.swift
//  Search
//
//  Created by Claude on 25/10/2025.
//

import SwiftUI
import SearchUse
import Models

@MainActor
@Observable
public final class SearchDataModel {
    private let getSearchUseCase: GetSearchUseCaseProtocol
    
    public var albums: [AppleMusicAlbumData] = []
    public var isLoading: Bool = false

    public init(getSearchUseCase: GetSearchUseCaseProtocol = GetSearchUseCase()) {
        self.getSearchUseCase = getSearchUseCase
    }

    public func searchAlbum(searchTerm: String) async throws {
        guard !searchTerm.isEmpty else {
            albums = []
            return
        }

        isLoading = true

        do {
            let results = try await getSearchUseCase.searchAlbums(searchTerm: searchTerm)
            albums = results
            isLoading = false
        } catch {
            albums = []
            isLoading = false
        }
    }
}
