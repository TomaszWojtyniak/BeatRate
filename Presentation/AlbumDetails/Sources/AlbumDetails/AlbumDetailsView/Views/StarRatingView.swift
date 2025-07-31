//
//  StarRatingView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 31/07/2025.
//

import SwiftUI
import Models

struct StarRatingView: View {
    @Binding var rating: Double
    let maxRating: Int = 10
    let totalScale: Double = 10.0
    @State private var lastTappedStar: Int = -1
    @State private var lastTapTime: Date = Date()
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<maxRating, id: \.self) { index in
                starView(for: index)
                    .foregroundColor(.yellow)
                    .onTapGesture {
                        handleStarTap(index: index)
                    }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    updateRating(from: value.location)
                }
        )
    }
    
    private func handleStarTap(index: Int) {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        if lastTappedStar == index && timeSinceLastTap < 0.5 {
            // Double tap - set to half star
            let newRating = Double(index) + 0.5
            updateRatingWithHaptic(newRating)
        } else {
            // Single tap - set to full star
            let newRating = Double(index + 1)
            updateRatingWithHaptic(newRating)
        }
        
        lastTappedStar = index
        lastTapTime = now
    }
    
    private func updateRatingWithHaptic(_ newRating: Double) {
        let clampedRating = min(max(newRating, 0), totalScale)
        if rating != clampedRating {
            rating = clampedRating
            // Light haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func starView(for index: Int) -> some View {
        let starRating = rating - Double(index)
        
        return ZStack {
            // Background star (empty)
            Image(systemName: "star")
                .font(.title3)
                .foregroundColor(.gray.opacity(0.3))
                .scaleEffect(1.3)
            
            // Star fill logic
            if starRating >= 1.0 {
                // Full star
                Image(systemName: "star.fill")
                    .font(.title3)
                    .scaleEffect(1.3)
            } else if starRating >= 0.5 {
                // Half star
                Image(systemName: "star.leadinghalf.filled")
                    .font(.title3)
                    .scaleEffect(1.3)
            }
        }
    }
    
    private func updateRating(from location: CGPoint) {
        let starWidth: CGFloat = 20 // Smaller width for 10 stars
        let totalWidth = CGFloat(maxRating) * starWidth
        let clampedX = min(max(location.x, 0), totalWidth)
        
        let starIndex = Int(clampedX / starWidth)
        let remainder = (clampedX.truncatingRemainder(dividingBy: starWidth)) / starWidth
        
        var newRating = Double(starIndex)
        
        if remainder > 0.75 {
            newRating += 1.0 // Full star
        } else if remainder > 0.25 {
            newRating += 0.5 // Half star
        }
        // else remains at current star base (empty additional star)
        
        let clampedRating = min(max(newRating, 0), totalScale)
        if rating != clampedRating {
            rating = clampedRating
            // Light haptic feedback for drag
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}

#Preview {
    StarRatingView(rating: .constant(7.8))
}
