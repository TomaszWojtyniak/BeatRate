import SwiftUI
import UIKit

extension Color {
    /// Resolves the colour the way SwiftUI would draw it in the given appearance.
    @MainActor
    func resolved(in scheme: ColorScheme = .light) -> Color.Resolved {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        return resolve(in: environment)
    }
}

enum ArtworkFixture {
    /// PNG bytes of a square cover split into four flat quadrants:
    /// top-left, top-right, bottom-left, bottom-right.
    static func quadrants(_ colors: [UIColor], side: CGFloat = 4) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let half = side / 2
        let origins = [CGPoint(x: 0, y: 0), CGPoint(x: half, y: 0), CGPoint(x: 0, y: half), CGPoint(x: half, y: half)]
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).pngData { context in
            for (color, origin) in zip(colors, origins) {
                color.setFill()
                context.fill(CGRect(origin: origin, size: CGSize(width: half, height: half)))
            }
        }
    }

    static func flat(_ color: UIColor, side: CGFloat = 4) -> Data {
        quadrants(Array(repeating: color, count: 4), side: side)
    }
}
