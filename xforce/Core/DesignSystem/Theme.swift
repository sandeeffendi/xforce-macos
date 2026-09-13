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

        /// Outcome colors. Always paired with a symbol and with words, never carrying the
        /// meaning on their own.
        static let success = SwiftUI.Color.green
        static let failure = SwiftUI.Color.red

        /// The wash behind a diff line that does not match. An asset-catalog color set
        /// rather than a tinted system red, so the dark appearance is authored rather than
        /// inherited from whatever 12% of red happens to look like on a dark surface.
        static let mismatchHighlight = SwiftUI.Color.diffMismatch

        /// The one place a mastery level becomes a colour, so the graph's nodes and its
        /// legend cannot drift apart.
        ///
        /// Authored color sets with Any + Dark variants rather than tinted system colors: a
        /// graph read at a glance needs four levels that stay apart in both appearances, and
        /// every one of them clears 3:1 against the window it is drawn on.
        ///
        /// `untouched` is a neutral grey and deliberately far from `weak`: "not yet attempted"
        /// and "attempted and struggling" are different things, and a learner who confused
        /// them would misread their own progress.
        static func mastery(_ level: MasteryLevel) -> SwiftUI.Color {
            switch level {
            case .untouched: SwiftUI.Color.masteryUntouched
            case .weak: SwiftUI.Color.masteryWeak
            case .developing: SwiftUI.Color.masteryDeveloping
            case .strong: SwiftUI.Color.masteryStrong
            }
        }

        /// The line between two concepts on the graph. A separator colour is too faint for a
        /// line that carries information rather than merely dividing two regions.
        static let graphEdge = SwiftUI.Color(nsColor: .secondaryLabelColor)

        /// The wash behind anything the model wrote, and never behind anything the learner
        /// wrote. Authored for both appearances for the same reason the mismatch wash is: a
        /// tint that is legible on white is not automatically legible on near-black, and this
        /// one carries meaning rather than decoration.
        static let modelSurface = SwiftUI.Color.modelSurface
    }

    enum Spacing {
        /// For stacks whose rows supply their own padding and must not be spaced apart.
        static let none: CGFloat = 0
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

        /// Monospaced, for anything that is literally console text: snippets, predictions,
        /// and the real output they are compared against.
        static let code = SwiftUI.Font.system(.body, design: .monospaced)

        /// The symbol that states the outcome. A text style rather than a point size, so it
        /// still tracks Dynamic Type.
        static let outcomeSymbol = SwiftUI.Font.system(.title2)
    }

    /// Fixed dimensions that are not spacing or radius, kept here for the same reason:
    /// so no view file carries a bare number.
    enum Size {
        static let predictionEditorHeight: CGFloat = 140
        static let explanationEditorHeight: CGFloat = 110
        static let contentMaxWidth: CGFloat = 760
        static let diffMarker: CGFloat = 14
        static let socraticAnswerEditorHeight: CGFloat = 96
        static let inspectorMinWidth: CGFloat = 260
        static let inspectorIdealWidth: CGFloat = 320
        static let inspectorMaxWidth: CGFloat = 420

        /// The concept graph. A node is a mark of this diameter with its name beneath it, and
        /// the canvas is inset by enough to keep a node authored at the very edge of the unit
        /// square fully on screen, name and all. Both scale with Dynamic Type where they are
        /// used, so these are the sizes at the default text size.
        static let graphNodeDiameter: CGFloat = 22
        static let graphNodeBorder: CGFloat = 2
        static let graphNodeLabelWidth: CGFloat = 120
        static let graphEdgeWidth: CGFloat = 1.5
        static let graphDash: CGFloat = 4
        static let masterySwatch: CGFloat = 12

        /// The symbol column in front of a rubric point, held at a fixed width so covered and
        /// missing rows start at the same place and the list reads as one column.
        static let feedbackMarker: CGFloat = 16
    }
}
