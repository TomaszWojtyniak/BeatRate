//
//  AlbumDetailsTilesView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 31/07/2025.
//

import SwiftUI
import CoreUI

struct AlbumDetailsTilesView: View {
    
    var body: some View {
        HStack(alignment: .center) {
            VStack {
                Text("Rating")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color.honeyYellow)
                    Text("7.8")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 40)
            
            VStack {
                Text("Released")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("2025")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 40)
            
            VStack {
                Text("Genre")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("POP")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

#Preview {
    AlbumDetailsTilesView()
}
