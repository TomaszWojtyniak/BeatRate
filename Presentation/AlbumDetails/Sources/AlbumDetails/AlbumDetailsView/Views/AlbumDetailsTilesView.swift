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
        HStack(spacing: 20) {
            
            // Rating tile
            VStack(spacing: 8) {
                Text("Rating")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    Text("7.8")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.thinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
            
            // Year tile
            VStack(spacing: 8) {
                Text("Released")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .font(.title3)
                    Text("2025")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.thinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
            
            // Genre tile
            VStack(spacing: 8) {
                Text("Genre")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "music.quarternote.3")
                        .foregroundColor(.purple)
                        .font(.title3)
                    Text("POP")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.thinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
    }
}

#Preview {
    AlbumDetailsTilesView()
}
