//
//  HomeSectionView.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI
import Models

struct HomeSectionView: View {
    
    let name: String
    let albums: [Album]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(name)
                .font(.system(.title2, weight: .medium))
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(albums) { album in
                        SectionAlbumView(album: album)
                    }
                }
            }
        }
    }
}

#Preview {
    HomeSectionView(name: "Section name", albums: [Album(title: "Album name", artist: "Artist name", cover: "")])
}
