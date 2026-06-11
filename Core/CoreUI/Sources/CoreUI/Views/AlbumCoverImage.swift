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

    let url: URL?
    let placeholderIconStyle: AppTextStyle?
    @State private var image: Image?

    public init(url: URL?, placeholderIconStyle: AppTextStyle? = .iconPlaceholder) {
        self.url = url
        self.placeholderIconStyle = placeholderIconStyle
    }

    public var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
        guard image == nil, let url else { return }
        // URLSession.shared goes through the shared URLCache, so a retry
        // after scrolling back is usually served from cache.
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else { return }
        image = Image(uiImage: uiImage)
    }
}

#Preview {
    AlbumCoverImage(url: nil)
        .frame(width: Size.thumbnailLarge, height: Size.thumbnailLarge)
}
