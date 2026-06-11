//
//  AlbumCoverImage.swift
//  CoreUI
//
//  Created by Tomasz Wojtyniak on 11/06/2026.
//

import SwiftUI
import UIKit

/// Remote album artwork with the standard music-note placeholder.
public struct AlbumCoverImage: View {

    @State private var image: Image?
    @State private var loadedUrl: URL?
    
    let url: URL?
    let contentMode: ContentMode
    let placeholderIconStyle: AppTextStyle?

    public init(url: URL?, contentMode: ContentMode = .fill, placeholderIconStyle: AppTextStyle? = .iconPlaceholder) {
        self.url = url
        self.contentMode = contentMode
        self.placeholderIconStyle = placeholderIconStyle
    }

    public var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color.albumPlaceholderColor)
                    .overlay {
                        if let placeholderIconStyle {
                            Image(systemName: "music.note")
                                .textStyle(placeholderIconStyle, color: .secondaryText)
                        }
                    }
            }
        }
        .task(id: url) {
            await loadIfNeeded()
        }
    }

    private func loadIfNeeded() async {
        if loadedUrl != url {
            image = nil
            loadedUrl = nil
        }
        guard image == nil, let url else { return }
        // URLSession.shared goes through the shared URLCache, so a retry
        // after scrolling back is usually served from cache.
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else { return }
        image = Image(uiImage: uiImage)
        loadedUrl = url
    }
}

#Preview {
    AlbumCoverImage(url: nil)
        .frame(width: Size.thumbnailLarge, height: Size.thumbnailLarge)
}
