//
//  ModelWrittenCard.swift
//  xforce
//

import SwiftUI

/// Marks its content as the model's words rather than the learner's.
///
/// The learner has to be able to tell, at a glance and forever, which sentences are theirs and
/// which a model produced — otherwise a fluent explanation they read once gets remembered as
/// one they wrote, which is exactly the illusion of understanding this app exists to break.
///
/// It lives in `Core/DesignSystem` beside `Theme.Color.modelSurface`, because the token and
/// the component are one rule rather than two: "model output looks like this" is a design-system
/// statement, and splitting the colour from the only thing allowed to use it would leave the
/// rule half-stated. The practice screen marks two different pieces of model output with it
/// today — the question during the loop and the reading in the feedback panel — so a screen
/// that renders model output and forgets to mark it is a missing view type, not a subtle
/// difference in padding.
///
/// The attribution is not only a wash and a border. The sparkles marker and the title are real
/// text, and VoiceOver is told the source explicitly, so the distinction survives for someone
/// who never sees the colour at all.
struct ModelWrittenCard<Content: View>: View {

    /// What this particular piece of model output is, in the learner's terms.
    let title: String

    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Label(title, systemImage: "sparkles")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
                // Said in words, because the sparkles and the wash say it only to people who
                // can see them — and who wrote it is the whole point of the component.
                .accessibilityLabel("\(title), from the on-device model")

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.medium)
        .background(Theme.Color.modelSurface, in: .rect(cornerRadius: Theme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(Theme.Color.brand)
        )
    }
}

#Preview("Light") {
    ModelWrittenCard(title: "A question about your reasoning") {
        Text("What would this print if the value were nil instead?")
            .font(Theme.Font.sectionTitle)
            .foregroundStyle(Theme.Color.primaryText)
    }
    .padding(Theme.Spacing.large)
    .background(Theme.Color.windowBackground)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ModelWrittenCard(title: "A question about your reasoning") {
        Text("What would this print if the value were nil instead?")
            .font(Theme.Font.sectionTitle)
            .foregroundStyle(Theme.Color.primaryText)
    }
    .padding(Theme.Spacing.large)
    .background(Theme.Color.windowBackground)
    .preferredColorScheme(.dark)
}
