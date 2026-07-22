//
//  LogomarkView.swift
//  CoreUI
//

import SwiftUI

/// The app logomark — the app icon artwork on its soft accent halo.
///
/// The artwork lives in the app target's asset catalog (`AppLogomark`), so it
/// resolves from `Bundle.main` at runtime and will not render in a CoreUI-only
/// SwiftUI preview.
public struct LogomarkView: View {
    /// Which piece of mark artwork to render.
    public enum Style {
        /// The app icon as shipped — gold star on its own opaque navy square.
        case fullColor
        /// Gold outline-and-star on transparency, for screens that want the mark
        /// to sit on the backdrop rather than on its own tile.
        case yellow

        var assetName: String {
            switch self {
            case .fullColor: "AppLogomark"
            case .yellow:    "AppYellowLogomark"
            }
        }
    }

    private let style: Style
    private let halo: CGFloat
    private let haloBlur: CGFloat

    /// - Parameters:
    ///   - style: Which mark artwork to render. Defaults to the app icon.
    ///   - halo: Diameter of the blurred accent circle behind the mark.
    ///   - haloBlur: Blur radius applied to that circle.
    public init(
        style: Style = .fullColor,
        halo: CGFloat = Halo.small,
        haloBlur: CGFloat = Blur.haloSmall
    ) {
        self.style = style
        self.halo = halo
        self.haloBlur = haloBlur
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentPrimarySoft)
                .frame(width: halo, height: halo)
                .blur(radius: haloBlur)

            Image(style.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: Size.logomark, height: Size.logomark)
                .clipShape(RoundedRectangle(cornerRadius: Radius.logomark, style: .continuous))
                .appShadow(.accentLift)
        }
    }
}
