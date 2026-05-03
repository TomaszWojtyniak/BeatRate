//
//  ArtworkColors.swift
//  CoreUI
//
//  Extracts two dominant accent colours from an image — typically an album
//  cover — for use as halo tints in `meshBackground(primary:secondary:)`.
//
//  Strategy: sample the four quadrants via `CIAreaAverage` (one GPU pass each),
//  score each by HSB saturation, pick the two most saturated. Avoids picking
//  the duller "background" tones and falls back gracefully on monochrome covers.
//

import SwiftUI
import CoreImage
import UIKit

public enum ArtworkColors {

    /// Downloads the image at `url` and returns two accent colours — primary
    /// and secondary — picked from the cover's four quadrants by saturation.
    /// Returns `nil` if the image can't be fetched or decoded.
    public nonisolated static func extract(from url: URL) async -> (primary: Color, secondary: Color)? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data),
              let cgImage = image.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        guard extent.width > 1, extent.height > 1 else { return nil }

        let halfW = extent.width / 2
        let halfH = extent.height / 2
        let regions: [CIVector] = [
            CIVector(x: extent.minX,        y: extent.minY + halfH, z: halfW, w: halfH), // top-left
            CIVector(x: extent.minX + halfW, y: extent.minY + halfH, z: halfW, w: halfH), // top-right
            CIVector(x: extent.minX,        y: extent.minY,         z: halfW, w: halfH), // bottom-left
            CIVector(x: extent.minX + halfW, y: extent.minY,         z: halfW, w: halfH)  // bottom-right
        ]

        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var samples: [(r: Double, g: Double, b: Double)] = []
        for region in regions {
            guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: region
            ]),
                  let output = filter.outputImage else { continue }

            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(
                output,
                toBitmap: &bitmap,
                rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: colorSpace
            )
            samples.append((
                r: Double(bitmap[0]) / 255.0,
                g: Double(bitmap[1]) / 255.0,
                b: Double(bitmap[2]) / 255.0
            ))
        }

        guard samples.count >= 2 else { return nil }

        // Rank by saturation; pick the most saturated as primary, then pick a
        // secondary that's reasonably distinct in hue (otherwise just take #2).
        let ranked = samples
            .map { (rgb: $0, sat: saturation($0)) }
            .sorted { $0.sat > $1.sat }

        let primary = ranked[0].rgb
        let secondary: (r: Double, g: Double, b: Double) = {
            // Prefer the most saturated remaining sample whose hue differs
            // from primary; otherwise fall back to the runner-up.
            let primaryHue = hue(primary)
            for candidate in ranked.dropFirst() {
                if abs(hue(candidate.rgb) - primaryHue) > 0.08 {
                    return candidate.rgb
                }
            }
            return ranked[1].rgb
        }()

        return (
            primary: Color(red: primary.r, green: primary.g, blue: primary.b),
            secondary: Color(red: secondary.r, green: secondary.g, blue: secondary.b)
        )
    }

    private nonisolated static func saturation(_ rgb: (r: Double, g: Double, b: Double)) -> Double {
        let maxC = max(rgb.r, rgb.g, rgb.b)
        let minC = min(rgb.r, rgb.g, rgb.b)
        return maxC == 0 ? 0 : (maxC - minC) / maxC
    }

    /// Hue in [0, 1]. Returns 0 for greys.
    private nonisolated static func hue(_ rgb: (r: Double, g: Double, b: Double)) -> Double {
        let maxC = max(rgb.r, rgb.g, rgb.b)
        let minC = min(rgb.r, rgb.g, rgb.b)
        let delta = maxC - minC
        guard delta > 0 else { return 0 }
        let h: Double
        if maxC == rgb.r {
            h = ((rgb.g - rgb.b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxC == rgb.g {
            h = (rgb.b - rgb.r) / delta + 2
        } else {
            h = (rgb.r - rgb.g) / delta + 4
        }
        return ((h / 6) + 1).truncatingRemainder(dividingBy: 1)
    }
}
