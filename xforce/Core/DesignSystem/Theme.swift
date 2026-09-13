//
//  Theme.swift
//  xforce
//

import SwiftUI

/// Design tokens. A namespace of static values, not runtime state.
///
/// Light and dark are handled by construction rather than by branching: colors are either
/// system semantic colors or asset-catalog color sets that declare both appearances. There
/// is deliberately no theme object in the environment and no theme switching.
enum Theme {

    enum Color {
        /// Brand colors — asset catalog color sets with Any + Dark variants.
        static let brand = SwiftUI.Color.brandPrimary
        static let surface = SwiftUI.Color.brandSurface

        /// System semantic colors: already adaptive and accessibility-aware.
        static let primaryText = SwiftUI.Color.primary
        static let secondaryText = SwiftUI.Color.secondary
        static let separator = SwiftUI.Color(nsColor: .separatorColor)
        static let windowBackground = SwiftUI.Color(nsColor: .windowBackgroundColor)
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 16
    }

    enum Font {
        static let screenTitle = SwiftUI.Font.system(.largeTitle, design: .rounded, weight: .semibold)
        static let sectionTitle = SwiftUI.Font.system(.headline)
        static let body = SwiftUI.Font.system(.body)
        static let caption = SwiftUI.Font.system(.caption)
    }
}
