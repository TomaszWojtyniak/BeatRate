//
//  DominantColor.swift
//  CoreUI
//
//  Asynchronously extracts a single representative colour from a remote image
//  by downscaling it to 1×1 pixel — Core Graphics averages colour values during
//  scale-down, giving us the perceptual average of the artwork in one fast pass.
//

import SwiftUI
import UIKit

public enum DominantColor {

    /// Downloads the image at `url`, downscales it to a single pixel, and reads
    /// back the averaged RGB value as a `Color`. Returns `nil` on any failure.
    public static func extract(from url: URL) async -> Color? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data),
              let cgImage = image.cgImage else { return nil }

        // Render the image into a 1×1 bitmap; the rasterizer averages all source
        // pixels into the single destination pixel for free.
        var pixel: [UInt8] = [0, 0, 0, 0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixel,
            width: 1, height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        return Color(
            red:   Double(pixel[0]) / 255,
            green: Double(pixel[1]) / 255,
            blue:  Double(pixel[2]) / 255
        )
    }
}
