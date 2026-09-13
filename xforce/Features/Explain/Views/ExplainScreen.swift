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

    var body: some View {
        ExplainScreenContent(content: content)
    }
}

private struct ExplainScreenContent: View {
    @State private var viewModel: ExplainViewModel

    /// - Note: `State(initialValue:)` is honoured only when the view's identity is first
    ///   established, so a service instance replaced later would not reach the view model.
    ///   Services are created once in `XforceApp` and never replaced, so that cannot happen
    ///   today; a change to service lifetime has to revisit this.
    init(content: ContentService) {
        _viewModel = State(initialValue: ExplainViewModel(content: content))
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

            if viewModel.isFeedbackLocked {
                LockedFeedbackNotice(hasRevealed: viewModel.phase >= .reveal)
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

/// Story 13: the constraint has to read as intentional rather than as a broken app.
private struct LockedFeedbackNotice: View {
    let hasRevealed: Bool

    var body: some View {
        Label {
            Text(message)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lock.fill")
                .foregroundStyle(Theme.Color.secondaryText)
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
    }

    private var message: String {
        hasRevealed
            ? "Feedback on your reasoning is still locked. It arrives once the questioning step is built."
            : "Feedback is locked until you commit to an output and a reason. Working it out yourself is the part that does the learning."
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
