//
//  MasteryDot.swift
//  xforce
//

import SwiftUI

/// The mark one mastery level is drawn as, used by the graph and by its legend so the two
/// cannot show the same level differently.
///
/// An untouched concept is an empty dashed ring rather than a paler disc. "Not yet attempted"
/// and "attempted and struggling" are different things, and a difference in shape survives a
/// colour-blind reader in a way a difference in hue does not.
struct MasteryDot: View {

    let level: MasteryLevel
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(level == .untouched ? Color.clear : Theme.Color.mastery(level))
            .overlay {
                Circle()
                    .strokeBorder(Theme.Color.mastery(level), style: borderStyle)
            }
            .frame(width: diameter, height: diameter)
    }

    private var borderStyle: StrokeStyle {
        level == .untouched
            ? StrokeStyle(lineWidth: Theme.Size.graphNodeBorder, dash: [Theme.Size.graphDash])
            : StrokeStyle(lineWidth: Theme.Size.graphNodeBorder)
    }
}

#Preview("Light") {
    MasteryDotPreview()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    MasteryDotPreview()
        .preferredColorScheme(.dark)
}

private struct MasteryDotPreview: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.large) {
            ForEach(MasteryLevel.allCases, id: \.self) { level in
                MasteryDot(level: level, diameter: Theme.Size.graphNodeDiameter)
            }
        }
        .padding(Theme.Spacing.large)
    }
}
