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
        HStack(spacing: 25) {

            VStack(spacing: 10) {
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
            .roundedMaterialBackground()
            
            VStack(spacing: 10) {
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
            .roundedMaterialBackground()
            
            VStack(spacing: 10) {
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
            .roundedMaterialBackground()
        }
    }
}

#Preview {
    VStack {
        AlbumDetailsTilesView()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.backgroundColor)
}
