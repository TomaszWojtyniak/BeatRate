//
//  RateAlbumView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 02/08/2025.
//

import SwiftUI
import CoreUI

struct RateAlbumView: View {

    @Binding var myRating: Double
    var onRatingFinalized: ((Double) -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text(myRating == 0 ? "Rate this album" : "My rating: \(String(format: "%.1f", myRating))")
                    .font(.system(.headline, weight: .semibold))
                Spacer()
            }

            StarRatingView(rating: $myRating, onRatingFinalized: onRatingFinalized)
                .padding(.vertical, 5)
        }
        .padding(20)
        .roundedMaterialBackground()
    }
}

#Preview {
    VStack {
        RateAlbumView(myRating: .constant(5.0))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.gray.opacity(0.25))
}
