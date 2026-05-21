//
//  MusicLibraryPermissionBullet.swift
//  Onboarding
//

import SwiftUI
import CoreUI

struct MusicLibraryPermissionBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: icon)
                .textStyle(.iconLabel, color: .accentPrimary)
                .frame(width: Size.touchTarget / 2, alignment: .center)
            Text(text)
                .textStyle(.body, color: .primaryTextOnDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
