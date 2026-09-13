//
//  ExplainScreen.swift
//  xforce
//

import SwiftUI

/// The practice screen: predict what a snippet prints, say why, then find out.
///
/// The screen is split in two on purpose, and this is the app's dependency-injection shape.
/// The working agreement has a view own its view model with `@State`, but `@Environment` is
/// not readable when that `@State`'s initial value is computed. So the outer view reads the
/// environment and the inner view owns a view model that is complete the moment it exists —
/// no optional dependency, and no "not configured yet" state for an intent method to defend.
/// Every later screen follows the same pattern.
struct ExplainScreen: View {
    @Environment(ContentService.self) private var content
    @Environment(\.feedback) private var feedback

    var body: some View {
        ExplainScreenContent(content: content, feedback: feedback)
    }
}

private struct ExplainScreenContent: View {
    @State private var viewModel: ExplainViewModel

    /// - Note: `State(initialValue:)` is honoured only when the view's identity is first
    ///   established, so a service instance replaced later would not reach the view model.
    ///   Services are created once in `XforceApp` and never replaced, so that cannot happen
    ///   today; a change to service lifetime has to revisit this.
    init(content: ContentService, feedback: any FeedbackService) {
        _viewModel = State(initialValue: ExplainViewModel(content: content, feedback: feedback))
    }

    var body: some View {
        ScrollView {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .padding(Theme.Spacing.xLarge)

            case .failed(let message):
                PlaceholderView(
                    title: "Nothing to practise",
                    message: message,
                    systemImage: "exclamationmark.triangle"
                )
                .padding(Theme.Spacing.xLarge)

            case .loaded:
                loop
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.windowBackground)
        .navigationTitle(AppSection.explain.title)
        .task { viewModel.load() }
        .inspector(isPresented: feedbackPresented) {
            FeedbackInspector(
                isLocked: viewModel.isFeedbackLocked,
                phase: viewModel.phase,
                generation: viewModel.generation
            )
            .inspectorColumnWidth(
                min: Theme.Size.inspectorMinWidth,
                ideal: Theme.Size.inspectorIdealWidth,
                max: Theme.Size.contentMaxWidth
            )
        }
    }

    /// The gate, expressed exactly once.
    ///
    /// Reading it derives the panel's presentation from the loop; writing it does nothing at
    /// all. That empty setter is the point: the inspector does not answer to a control, so
    /// there is no control anywhere that can open the feedback early, and none can be added
    /// by accident later. What the panel *contains* is derived from the phase in the same
    /// way, which is why the gate is one value rather than a scattering of `.disabled`.
    private var feedbackPresented: Binding<Bool> {
        Binding(get: { viewModel.isInspectorVisible }, set: { _ in })
    }

    @ViewBuilder
    private var loop: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            if let concept = viewModel.concept {
                ConceptHeader(concept: concept)
            }

            if let snippet = viewModel.snippet {
                SnippetCard(code: snippet.code)
            }

            if viewModel.phase == .prompt {
                promptFields
            } else {
                RevealPanel(
                    diff: viewModel.diff,
                    expectedOutput: viewModel.expectedOutput,
                    outcome: viewModel.outcome
                )
            }

            if viewModel.isGenerating {
                GeneratingNotice(cancel: viewModel.cancelGenerating)
            }

            if viewModel.phase == .socratic, let question = viewModel.socraticQuestion {
                socraticFields(question: question)
            }
        }
        .frame(maxWidth: Theme.Size.contentMaxWidth, alignment: .leading)
        .padding(Theme.Spacing.xLarge)
    }

    @ViewBuilder
    private var promptFields: some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            FieldLabel(
                title: "Console output",
                hint: "Type exactly what this prints, line for line."
            )

            TextEditor(text: $viewModel.prediction)
                .font(Theme.Font.code)
                .scrollContentBackground(.hidden)
                .padding(Theme.Spacing.small)
                .frame(height: Theme.Size.predictionEditorHeight)
                .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .strokeBorder(Theme.Color.separator)
                )
                .accessibilityLabel("Console output")

            FieldLabel(
                title: "Your reasoning",
                hint: "Why does it print that? Your own words, not the snippet's."
            )

            TextEditor(text: $viewModel.explanation)
                .font(Theme.Font.body)
                .scrollContentBackground(.hidden)
                .padding(Theme.Spacing.small)
                .frame(height: Theme.Size.explanationEditorHeight)
                .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .strokeBorder(Theme.Color.separator)
                )
                .accessibilityLabel("Your reasoning")

            Button("Reveal the real output") {
                viewModel.submit()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.canSubmit == false)
        }
    }

    /// The question, alone. The feedback is still locked behind it, which is what makes the
    /// question real rather than rhetorical.
    @ViewBuilder
    private func socraticFields(question: String) -> some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            SocraticQuestionCard(question: question)

            TextEditor(text: $viewModel.socraticAnswer)
                .font(Theme.Font.body)
                .scrollContentBackground(.hidden)
                .padding(Theme.Spacing.small)
                .frame(height: Theme.Size.socraticAnswerEditorHeight)
                .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .strokeBorder(Theme.Color.separator)
                )
                .accessibilityLabel("Your answer to the question")

            HStack(spacing: Theme.Spacing.medium) {
                Button("Answer") {
                    viewModel.answer()
                }
                .buttonStyle(.borderedProminent)

                // Never disabled: a loop that traps the learner is worse than an unanswered
                // question, and a skip is recorded as its own thing rather than as silence.
                Button("Nothing to add") {
                    viewModel.skip()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Pieces

private struct ConceptHeader: View {
    let concept: Concept

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text(concept.name)
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.Color.primaryText)

            Text(concept.summary)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SnippetCard: View {
    let code: String

    var body: some View {
        Text(code)
            .font(Theme.Font.code)
            .foregroundStyle(Theme.Color.primaryText)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.medium)
            .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .strokeBorder(Theme.Color.separator)
            )
            .accessibilityLabel("Swift snippet")
    }
}

private struct FieldLabel: View {
    let title: String
    let hint: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
            Text(title)
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.primaryText)

            Text(hint)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
        }
    }
}

/// The ground truth, shown only after the learner has committed.
private struct RevealPanel: View {
    let diff: OutputDiff?
    let expectedOutput: String?
    let outcome: PredictionOutcome?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            if let outcome {
                OutcomeBanner(outcome: outcome)
            }

            if let diff {
                DiffTable(diff: diff)
            }

            if let expectedOutput {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Real output")
                        .font(Theme.Font.sectionTitle)
                        .foregroundStyle(Theme.Color.primaryText)

                    Text(expectedOutput)
                        .font(Theme.Font.code)
                        .foregroundStyle(Theme.Color.primaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.medium)
                        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
                }
            }
        }
    }
}

/// Says plainly whether the learner was right. Colour never carries the meaning on its own:
/// there is a symbol and there are words.
private struct OutcomeBanner: View {
    let outcome: PredictionOutcome

    var body: some View {
        Label {
            Text(title)
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.primaryText)
        } icon: {
            Image(systemName: symbol)
                .font(Theme.Font.outcomeSymbol)
                .foregroundStyle(tint)
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(Theme.Color.separator)
        )
    }

    private var title: String {
        switch outcome {
        case .correct: "You predicted the output correctly."
        case .incorrect: "That is not what this prints."
        }
    }

    private var symbol: String {
        switch outcome {
        case .correct: "checkmark.circle.fill"
        case .incorrect: "xmark.circle.fill"
        }
    }

    private var tint: Color {
        switch outcome {
        case .correct: Theme.Color.success
        case .incorrect: Theme.Color.failure
        }
    }
}

/// The prediction and the real output side by side, with the lines that differ marked.
private struct DiffTable: View {
    let diff: OutputDiff

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack(spacing: Theme.Spacing.medium) {
                Spacer().frame(width: Theme.Size.diffMarker)
                columnTitle("What you predicted")
                columnTitle("What it prints")
            }
            // Matches the rows' own padding so the three columns line up.
            .padding(.horizontal, Theme.Spacing.small)

            VStack(spacing: Theme.Spacing.none) {
                ForEach(diff.lines) { line in
                    DiffRow(line: line)
                }
            }
            .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .strokeBorder(Theme.Color.separator)
            )
        }
    }

    private func columnTitle(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DiffRow: View {
    let line: OutputDiff.Line

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.medium) {
            // The wash alone would put the whole meaning of the row in a colour.
            marker
            cell(line.predicted)
            cell(line.expected)
        }
        .padding(Theme.Spacing.small)
        .background {
            if line.matches == false {
                Theme.Color.mismatchHighlight
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Held in the layout even when it matches, so rows never shift width.
    private var marker: some View {
        Image(systemName: "xmark")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.failure)
            .opacity(line.matches ? 0 : 1)
            .frame(width: Theme.Size.diffMarker)
            .accessibilityHidden(true)
    }

    private func cell(_ text: String?) -> some View {
        Text(text ?? "—")
            .font(Theme.Font.code)
            .foregroundStyle(text == nil ? Theme.Color.secondaryText : Theme.Color.primaryText)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilityLabel: String {
        let state = line.matches ? "matches" : "differs"
        return "Line \(line.number) \(state). You predicted \(line.predicted ?? "nothing"). It prints \(line.expected ?? "nothing")."
    }
}

/// The model asking, not telling. Marked as the model's words so the learner never
/// misremembers them as their own.
private struct SocraticQuestionCard: View {
    let question: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Label("A question about your reasoning", systemImage: "sparkles")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)

            Text(question)
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.medium)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(Theme.Color.brand)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("A question about your reasoning. \(question)")
    }
}

/// Stories 34 and 35: a pause has to read as work rather than as a freeze, and it has to be
/// stoppable.
private struct GeneratingNotice: View {
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            ProgressView()
                .controlSize(.small)

            Text("Reading your reasoning…")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)

            Spacer()

            Button("Stop", action: cancel)
                .buttonStyle(.bordered)
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
    }
}

/// Stories 13 and 14: the panel is on screen for the whole loop, and what it holds is
/// decided by the phase rather than by anything the learner can press. The constraint has to
/// read as intentional rather than as a broken app, which it cannot do if it is invisible.
private struct FeedbackInspector: View {
    let isLocked: Bool
    let phase: LoopPhase
    let generation: FeedbackGeneration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Label {
                    Text("Feedback")
                        .font(Theme.Font.sectionTitle)
                        .foregroundStyle(Theme.Color.primaryText)
                } icon: {
                    Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                        .foregroundStyle(Theme.Color.secondaryText)
                }

                Text(message)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.large)
        }
        .background(Theme.Color.windowBackground)
        .accessibilityLabel(isLocked ? "Feedback, locked" : "Feedback")
    }

    /// What the model did takes precedence over where the loop is, because a learner whose
    /// Mac has no model needs to be told that and not told to keep going.
    private var message: String {
        switch generation {
        case .idle, .asked:
            phaseMessage
        case .running:
            "The model is reading your reasoning. The feedback stays locked until you have been asked about it and have answered."
        case .cancelled:
            "You stopped the question before it arrived, so there is nothing to show here. Nothing else in the loop is affected."
        case .unavailable(let availability):
            availability.message ?? phaseMessage
        case .failed(let explanation):
            explanation
        }
    }

    private var phaseMessage: String {
        switch phase {
        case .prompt:
            "Locked until you commit to an output and a reason. Working it out yourself is the part that does the learning."
        case .reveal:
            "Locked until you have been asked about your reasoning and have answered."
        case .socratic:
            "Answer the question or say you have nothing to add, and this unlocks."
        case .feedback, .committed:
            "Unlocked. Which rubric points your explanation covered, what it missed and any misconception it showed arrive once the feedback step is built."
        }
    }
}

#Preview("Light") {
    ExplainScreen()
        .environment(Router())
        .environment(ContentService())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ExplainScreen()
        .environment(Router())
        .environment(ContentService())
        .preferredColorScheme(.dark)
}
