//
//  ModelReadingCard.swift
//  xforce
//

import SwiftUI

/// What the model made of one explanation: what it credited, what it did not, and any wrong
/// belief it named — all of it inside the card that says the words are the model's.
///
/// One component rather than two, because the same reading is shown twice in the app: live, in
/// the practice screen's feedback panel, and again in the graph inspector when the learner
/// reads back a note they wrote weeks ago. A second rendering would be a second chance for the
/// two to drift — in wording, in ordering, or in the one thing that must never drift, which is
/// whether the learner can tell the model's writing from their own.
///
/// It lives in `Core/DesignSystem` for the reason anything does: two features need it, and
/// features may not import each other. It wraps ``ModelWrittenCard`` rather than restating the
/// attribution, so "model output looks like this" stays one rule in one place.
struct ModelReadingCard: View {

    let reading: StructuredFeedback

    /// What the slot is called wherever a reading would go — including where one is missing,
    /// so the running order keeps the same heading when there was no model to ask.
    static let title = "Read by the on-device model"

    var body: some View {
        ModelWrittenCard(title: Self.title) {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                RubricList(
                    title: "What you got right",
                    points: reading.covered,
                    symbol: "checkmark.circle.fill",
                    tint: Theme.Color.success,
                    emptyMessage: "None of the rubric came through in what you wrote."
                )

                RubricList(
                    title: "What is missing",
                    points: reading.missing,
                    symbol: "circle.dashed",
                    tint: Theme.Color.secondaryText,
                    emptyMessage: "Nothing. Your explanation covered every point."
                )

                if reading.hasMisconception {
                    MisconceptionList(misconceptions: reading.misconceptions)
                }
            }
        }
    }
}

/// One half of the rubric. Both halves are drawn by the same view because they are the same
/// list split in two — which is exactly what computing the complement made them.
private struct RubricList: View {
    let title: String
    let points: [RubricPoint]
    let symbol: String
    let tint: Color
    let emptyMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
            Text(title)
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.primaryText)

            if points.isEmpty {
                Text(emptyMessage)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(points) { point in
                    row(point)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The symbol differs as well as the colour, and the heading says which list this is, so
    /// nothing here depends on telling green from grey.
    private func row(_ point: RubricPoint) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.small) {
            Image(systemName: symbol)
                .font(Theme.Font.caption)
                .foregroundStyle(tint)
                .frame(width: Theme.Size.feedbackMarker)
                .accessibilityHidden(true)

            Text(point.text)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(point.text)")
    }
}

/// Story 29: a detected misconception is named **and corrected**, because flagging a wrong
/// belief without saying what replaces it leaves the learner knowing only that they are wrong.
private struct MisconceptionList: View {
    let misconceptions: [Misconception]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("Worth replacing")
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.primaryText)

            ForEach(misconceptions) { misconception in
                VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                    Label {
                        Text(misconception.name)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.failure)
                    }

                    Text(misconception.correction)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Worth replacing. \(misconception.name). \(misconception.correction)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Light") {
    ModelReadingCardPreview()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ModelReadingCardPreview()
        .preferredColorScheme(.dark)
}

private struct ModelReadingCardPreview: View {

    var body: some View {
        ScrollView {
            ModelReadingCard(reading: Self.reading)
                .padding(Theme.Spacing.large)
        }
        .frame(width: Theme.Size.inspectorIdealWidth)
        .background(Theme.Color.windowBackground)
    }

    /// A reading with every section populated, including the conditional one, so the wash
    /// marking model-written text can be checked in both appearances.
    private static var reading: StructuredFeedback {
        let concept = Concept(
            id: "optionals",
            name: "Optionals",
            summary: "A value that may be absent.",
            position: ConceptPosition(x: 0.5, y: 0.5),
            prerequisites: [],
            related: [],
            rubric: [
                RubricPoint(number: 1, text: "An optional either holds a value or holds nil."),
                RubricPoint(number: 2, text: "Printing an optional shows the Optional(...) wrapper."),
                RubricPoint(number: 3, text: "The value has to be unwrapped before it can be used."),
            ],
            misconceptions: [
                Misconception(
                    id: "printing-shows-the-value",
                    name: "Printing an optional prints the value it holds",
                    correction: "print describes the optional itself, so an Int? holding 5 prints as Optional(5)."
                )
            ]
        )

        return StructuredFeedback(
            concept: concept,
            coveredRubricPoints: [1],
            detectedMisconceptionIDs: ["printing-shows-the-value"]
        )
    }
}
