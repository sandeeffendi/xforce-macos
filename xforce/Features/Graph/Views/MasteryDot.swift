//
//  MasteryDot.swift
//  xforce
//

import SwiftUI

/// The mark one mastery level is drawn as, used by the graph and by its legend so the two
/// cannot show the same level differently.
///
/// Colour is never the only difference between two levels. The mark is a ring that fills in as
/// the concept is understood — empty and dashed when it has never been attempted, a small disc
/// when it is being struggled with, whole when it is solid. A learner who cannot tell the red
/// from the green still sees how full the mark is, and "not yet attempted" stays visibly apart
/// from "attempted and struggling" whatever the screen or the eye does to the hue.
struct MasteryDot: View {

    let level: MasteryLevel
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.Color.mastery(level))
                .frame(width: diameter * level.markFill, height: diameter * level.markFill)

            Circle()
                .strokeBorder(Theme.Color.mastery(level), style: borderStyle)
        }
        .frame(width: diameter, height: diameter)
    }

    /// The ring around an untouched concept is dashed as well as empty, so the level reads as
    /// "nothing here yet" rather than as a very small amount of progress.
    private var borderStyle: StrokeStyle {
        level == .untouched
            ? StrokeStyle(lineWidth: Theme.Size.graphNodeBorder, dash: [Theme.Size.graphDash])
            : StrokeStyle(lineWidth: Theme.Size.graphNodeBorder)
    }
}

private extension MasteryLevel {

    /// How much of the mark is filled in, as a fraction of its diameter. A proportion of the
    /// mark rather than a size, so it holds at any diameter and under any text size.
    var markFill: CGFloat {
        switch self {
        case .untouched: 0
        case .weak: 0.4
        case .developing: 0.7
        case .strong: 1
        }
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
