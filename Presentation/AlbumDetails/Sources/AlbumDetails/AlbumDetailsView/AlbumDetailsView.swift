//
//  AlbumDetailsView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Models

struct AlbumDetailsView: View {
    
    let album: AlbumModel
    @State private var myRating: Double = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                AlbumDetailsMainSectionView(album: album)
                    .padding(.horizontal)
                
                VStack(spacing: 24) {
                    AlbumDetailsTilesView()
                        .padding(.top, 32)
                        .padding(.horizontal, 50)
                    
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.title2)
                            Text("Rate this album")
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                            Spacer()
                        }
                        
                        StarRatingView(rating: $myRating)
                            .padding(.vertical, 8)
                        
                        if myRating > 0 {
                            Text("Your rating: \(myRating, specifier: "%.1f")/10")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                    )
                    .padding(.horizontal, 50)
                    .animation(.easeInOut(duration: 0.3), value: myRating)
                    
                    
                    // Bottom spacing
                    Spacer(minLength: 100)
                }
                .background(
                    // Subtle background gradient
                    LinearGradient(
                        colors: [Color.clear, Color(UIColor.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

#Preview {
    AlbumDetailsView(album: AlbumModel(title: "Album title Album title Album title Album title Album title Album title Album title Album title Album title Album title", artist: "Artist", coverUrl: nil))
}
