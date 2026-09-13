//
//  ConceptInspector.swift
//  xforce
//

import SwiftUI

/// One concept's whole record: what it is, a way to practise it now, and every note the
/// learner has written about it in the order they wrote them.
///
/// Oldest first, deliberately. A concept is a long-lived entity with many notes over time, and
/// the sequence is the evidence of understanding changing — which is the same reason notes are
/// immutable. Read downwards, it is the learner watching what they used to think turn into
/// what they think now.
///
/// The learner's writing and the model's are told apart here exactly as they are in the live
/// panel, through the same two components. That is the point of reusing them rather than
/// drawing this surface separately: a fluent sentence the model produced must never be
/// misremembered as one the learner wrote, and a second rendering would be a second chance for
/// the two to disagree.
struct ConceptInspector: View {

    let concept: Concept
    let history: [NoteEntry]

    /// Starts a session on this concept. The screen turns it into a push; the inspector only
    /// says that the learner asked.
    let onStartSession: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                header

                PractiseControl(action: onStartSession)

                Divider()

                if history.isEmpty {
                    emptyHistory
                } else {
                    historyList
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.large)
        }
        .background(Theme.Color.windowBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
            Text(concept.name)
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.primaryText)

            Text(concept.summary)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// An invitation rather than a verdict. "You have not written about this yet" is a fact
    /// about where the learner has been, not a mark against them, and the words say so.
    private var emptyHistory: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Label("Nothing written about \(concept.name) yet", systemImage: "square.and.pencil")
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.primaryText)

            Text("""
                Start a session and what you write becomes the first entry here. Everything you \
                commit stays, in the order you wrote it, so you can watch your understanding of \
                \(concept.name) change.
                """)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.medium)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
        .accessibilityElement(children: .combine)
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            Text(historyTitle)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)

            ForEach(history) { entry in
                NoteEntryCard(entry: entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var historyTitle: String {
        history.count == 1
            ? "1 session, oldest first"
            : "\(history.count) sessions, oldest first"
    }
}

/// The deliberate revisit: a session on this concept, now.
///
/// It stands in for the scheduled review mode this milestone leaves out, which is why it is
/// the inspector's primary control and is there whether or not there is any history to read.
private struct PractiseControl: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
            Button("Practise this concept", action: action)
                .buttonStyle(.borderedProminent)

            Text("You will get a snippet you have not seen, or the one you saw longest ago.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One session, read back whole.
///
/// The running order is the order the learner lived it: the snippet, what they said it would
/// print against what it printed, their reasoning, the question they were asked and what they
/// said back, and last the model's reading of it all.
private struct NoteEntryCard: View {
    let entry: NoteEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            heading

            if let code = entry.code {
                CodeBlock(text: code)
            } else {
                // The note outlives the content it names. Saying so is better than a blank,
                // because the learner's own words below are still worth reading.
                Text("This snippet is no longer part of the content.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LabelledText(title: "What you predicted", text: entry.prediction, isCode: true)

            if let expectedOutput = entry.expectedOutput {
                LabelledText(title: "What it printed", text: expectedOutput, isCode: true)
            }

            LabelledText(title: "Your reasoning", text: entry.explanation, isCode: false)

            socraticExchange

            reading
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.medium)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(Theme.Color.separator)
        )
    }

    /// Which session this is, when it was, and what it did to the concept's standing. The
    /// outcome is a symbol and words, never a colour on its own.
    private var heading: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
            Text("Session \(entry.order) · \(entry.writtenAt.formatted(date: .abbreviated, time: .shortened))")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)

            Label {
                Text(entry.outcome.historyTitle)
                    .font(Theme.Font.sectionTitle)
                    .foregroundStyle(Theme.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                SessionOutcomeSymbol(outcome: entry.outcome)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// The question in the card that marks it as the model's, the answer plainly outside it —
    /// the same shape the loop puts them in while the session is live.
    @ViewBuilder
    private var socraticExchange: some View {
        if let question = entry.socraticQuestion {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                ModelWrittenCard(title: "A question about your reasoning") {
                    Text(question)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let answer = entry.socraticAnswer {
                    LabelledText(title: "Your answer", text: answer, isCode: false)
                } else {
                    Text("You had nothing to add.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.secondaryText)
                }
            }
        } else {
            Text("No question was asked in this session — there was no model available.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The model's half, in the component that says so. Absent rather than empty when nothing
    /// read the explanation: a rubric with every point missing would tell the learner they
    /// failed at something nobody ever read.
    @ViewBuilder
    private var reading: some View {
        if let reading = entry.reading {
            ModelReadingCard(reading: reading)
        } else {
            Text("No model read this explanation, so there is nothing it judged.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A heading and the learner's own words under it, presented plainly — which is what marks
/// them as the learner's. Nothing the model wrote is ever drawn this way.
private struct LabelledText: View {
    let title: String
    let text: String
    let isCode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)

            Text(text.isEmpty ? "—" : text)
                .font(isCode ? Theme.Font.code : Theme.Font.body)
                .foregroundStyle(text.isEmpty ? Theme.Color.secondaryText : Theme.Color.primaryText)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The snippet as it was shown at the time, rendered as code rather than as prose.
private struct CodeBlock: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Font.code)
            .foregroundStyle(Theme.Color.primaryText)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.small)
            .background(Theme.Color.windowBackground, in: .rect(cornerRadius: Theme.Radius.small))
            .accessibilityLabel("Swift snippet")
    }
}

/// The mark one session outcome is drawn as.
///
/// One view rather than a symbol and a tint that travel separately, for the same reason the
/// practice screen's `OutcomeSymbol` is one: the two halves of a mark cannot disagree if they
/// cannot be used apart. Colour never carries the meaning alone — the words beside it do.
private struct SessionOutcomeSymbol: View {
    let outcome: SessionOutcome

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(tint)
    }

    private var symbol: String {
        switch outcome {
        case .mastered: "checkmark.circle.fill"
        case .fragile: "exclamationmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    private var tint: Color {
        switch outcome {
        case .mastered: Theme.Color.success
        case .fragile: Theme.Color.brand
        case .failed: Theme.Color.failure
        }
    }
}

private extension SessionOutcome {

    /// What the session did, in words. The history is read long after the session, so "box
    /// unchanged" would mean nothing — what the learner needs is what they did.
    var historyTitle: String {
        switch self {
        case .mastered: "Predicted correctly"
        case .fragile: "Correct, with a misconception showing"
        case .failed: "Prediction did not match"
        }
    }
}

#Preview("History, light") {
    ConceptInspectorPreview(history: .preview)
        .preferredColorScheme(.light)
}

#Preview("History, dark") {
    ConceptInspectorPreview(history: .preview)
        .preferredColorScheme(.dark)
}

#Preview("Empty, light") {
    ConceptInspectorPreview(history: [])
        .preferredColorScheme(.light)
}

#Preview("Empty, dark") {
    ConceptInspectorPreview(history: [])
        .preferredColorScheme(.dark)
}

private struct ConceptInspectorPreview: View {
    let history: [NoteEntry]

    var body: some View {
        ConceptInspector(concept: .preview, history: history, onStartSession: {})
            .frame(width: Theme.Size.inspectorIdealWidth)
    }
}

private extension Concept {

    /// A concept of the shape the inspector renders, built here rather than read from the
    /// bundle, so the preview holds still while the content is authored in a lane of its own.
    static var preview: Concept {
        Concept(
            id: "optionals",
            name: "Optionals",
            summary: "A value that may be absent, and the wrapper that says so.",
            position: ConceptPosition(x: 0.5, y: 0.5),
            prerequisites: [],
            related: [],
            rubric: [
                RubricPoint(number: 1, text: "An optional either holds a value or holds nil."),
                RubricPoint(number: 2, text: "Printing an optional shows the Optional(...) wrapper."),
            ],
            misconceptions: [
                Misconception(
                    id: "printing-shows-the-value",
                    name: "Printing an optional prints the value it holds",
                    correction: "print describes the optional itself, so an Int? holding 5 prints as Optional(5)."
                )
            ]
        )
    }
}

private extension [NoteEntry] {

    /// Two sessions a month apart, the second better than the first — which is the whole thing
    /// the history exists to let the learner see.
    static var preview: [NoteEntry] {
        let concept = Concept.preview

        return [
            NoteEntry(
                order: 1,
                writtenAt: Date(timeIntervalSince1970: 1_700_000_000),
                outcome: .failed,
                code: "let age: Int? = 5\nprint(age)",
                expectedOutput: "Optional(5)",
                prediction: "5",
                explanation: "The optional holds five, so printing it prints five.",
                socraticQuestion: "What told you the wrapper would be gone?",
                socraticAnswer: "Nothing. I assumed print unwraps it.",
                reading: StructuredFeedback(
                    concept: concept,
                    coveredRubricPoints: [1],
                    detectedMisconceptionIDs: ["printing-shows-the-value"]
                )
            ),
            NoteEntry(
                order: 2,
                writtenAt: Date(timeIntervalSince1970: 1_702_600_000),
                outcome: .mastered,
                code: "let name: String? = \"Ada\"\nprint(name)",
                expectedOutput: "Optional(\"Ada\")",
                prediction: "Optional(\"Ada\")",
                explanation: "print describes the optional itself, so the wrapper is part of what it writes.",
                socraticQuestion: "What would change if the value were nil?",
                socraticAnswer: nil,
                reading: StructuredFeedback(
                    concept: concept,
                    coveredRubricPoints: [1, 2],
                    detectedMisconceptionIDs: []
                )
            ),
        ]
    }
}
