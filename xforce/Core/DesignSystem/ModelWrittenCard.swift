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
/// It lives in `Core/DesignSystem` rather than in the practice feature because the distinction
/// has to hold **wherever** the content appears. The question shown during the loop, the
/// reading shown in the feedback panel, and the same two replayed later from a stored note are
/// all the same claim about who wrote what, so they are all the same component. A feature that
/// renders model output and forgets to mark it is then a missing view type, not a subtle
/// difference in padding.
///
/// The attribution is real text, not only a colour: VoiceOver reads "From the on-device model"
/// aloud, so the distinction survives for someone who never sees the wash or the border.
struct ModelWrittenCard<Content: View>: View {

    /// What this particular piece of model output is, in the learner's terms.
    let title: String

    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Label(title, systemImage: "sparkles")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)

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
