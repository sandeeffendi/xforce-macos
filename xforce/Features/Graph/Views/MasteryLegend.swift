//
//  MasteryLegend.swift
//  xforce
//

import SwiftUI

/// What the colours and the lines on the graph mean, in words.
///
/// The graph is the one screen that says something about the learner purely through colour, so
/// the colour is never left to carry the meaning on its own — the same rule the outcome colours
/// in the practice loop follow.
struct MasteryLegend: View {

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            // The legend is what the colours mean, so it must never be the thing that gets
            // truncated. At a large text size the four levels stack instead of shrinking.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.large) {
                    ForEach(MasteryLevel.allCases, id: \.self) { level in
                        swatch(for: level)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                    ForEach(MasteryLevel.allCases, id: \.self) { level in
                        swatch(for: level)
                    }
                }
            }

            Text("A solid line is a prerequisite. A dashed line is a related concept.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.medium)
        .background(Theme.Color.surface)
    }

    private func swatch(for level: MasteryLevel) -> some View {
        HStack(spacing: Theme.Spacing.xSmall) {
            MasteryDot(level: level, diameter: Theme.Size.masterySwatch)

            Text(level.title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    MasteryLegend()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    MasteryLegend()
        .preferredColorScheme(.dark)
}
