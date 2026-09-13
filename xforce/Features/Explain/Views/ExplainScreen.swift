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

    /// The concept the learner asked to practise, or `nil` when the loop chooses for itself.
    ///
    /// Arrives from the route rather than from a shared object, which is what lets the graph
    /// send the learner here by pushing a value and lets the same screen serve both doors.
    var conceptID: String?

    @Environment(ContentService.self) private var content
    @Environment(\.feedback) private var feedback
    @Environment(SchedulingService.self) private var scheduling

    var body: some View {
        ExplainScreenContent(
            content: content,
            feedback: feedback,
            scheduling: scheduling,
            conceptID: conceptID
        )
    }
}

private struct ExplainScreenContent: View {
    @State private var viewModel: ExplainViewModel

    /// - Note: `State(initialValue:)` is honoured only when the view's identity is first
    ///   established, so a service instance replaced later would not reach the view model.
    ///   Services are created once in `XforceApp` and never replaced, so that cannot happen
    ///   today; a change to service lifetime has to revisit this.
    init(
        content: ContentService,
        feedback: any FeedbackService,
        scheduling: SchedulingService,
        conceptID: String?
    ) {
        _viewModel = State(
            initialValue: ExplainViewModel(
                content: content,
                feedback: feedback,
                scheduling: scheduling,
                conceptID: conceptID
            )
        )
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
            FeedbackInspector(viewModel: viewModel)
            .inspectorColumnWidth(
                min: Theme.Size.inspectorMinWidth,
                ideal: Theme.Size.inspectorIdealWidth,
                max: Theme.Size.inspectorMaxWidth
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

            if let progress = viewModel.progress, viewModel.phase == .committed {
                CommittedPanel(
                    conceptName: viewModel.concept?.name ?? "",
                    progress: progress,
                    hasNextSnippet: viewModel.nextSnippet != nil,
                    onContinue: { viewModel.startNextSnippet() }
                )
            } else if viewModel.canCommit {
                commitControls
            }
        }
        .frame(maxWidth: Theme.Size.contentMaxWidth, alignment: .leading)
        .padding(Theme.Spacing.xLarge)
    }

    /// Writing the session down is the learner's own act, so it is a control rather than
    /// something that happens to them the moment the panel unlocks.
    @ViewBuilder
    private var commitControls: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Button("Save this session") {
                viewModel.commit()
            }
            .buttonStyle(.borderedProminent)

            Text("Your note is written once and never edited. It records what you thought here.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)

            if let commitFailure = viewModel.commitFailure {
                Label {
                    Text(commitFailure)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Color.failure)
                }
            }
        }
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
            OutcomeSymbol(outcome: outcome)
                .font(Theme.Font.outcomeSymbol)
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
}

/// The tick or the cross, wherever the outcome is stated.
///
/// One view rather than a symbol-and-tint pair repeated at each site, so the reveal and the
/// feedback panel cannot end up disagreeing about what "correct" looks like. The size is left
/// to the caller, which is the only thing that genuinely differs between them.
private struct OutcomeSymbol: View {
    let outcome: PredictionOutcome

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(tint)
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

/// What the commit did: the note is written, and the concept has moved through the schedule.
///
/// Which box the concept landed in is stated plainly, because it is the whole consequence of
/// having been right or wrong and the learner is entitled to see it before moving on. When it
/// next falls due is deliberately *not* shown: nothing re-engages the learner on a due date in
/// this version, and a date nothing acts on is a promise the app cannot keep.
private struct CommittedPanel: View {
    let conceptName: String
    let progress: ConceptProgress
    let hasNextSnippet: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Label {
                VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                    Text("Saved to your notes")
                        .font(Theme.Font.sectionTitle)
                        .foregroundStyle(Theme.Color.primaryText)

                    Text(scheduleSummary)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .font(Theme.Font.outcomeSymbol)
                    .foregroundStyle(Theme.Color.brand)
            }

            if hasNextSnippet {
                Button("Next snippet") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(Theme.Color.separator)
        )
    }

    private var scheduleSummary: String {
        "\(conceptName) is now in box \(progress.box) of \(ConceptProgress.lastBox)."
    }
}

/// The model asking, not telling. Marked as the model's words — through the same component
/// every other piece of model output uses — so the learner never misremembers them as theirs.
private struct SocraticQuestionCard: View {
    let question: String

    var body: some View {
        ModelWrittenCard(title: "A question about your reasoning") {
            Text(question)
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        // One question is one thing to hear, attribution included. The panel's card is not
        // combined, because its lists have to be navigable point by point.
        .accessibilityElement(children: .combine)
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

/// Stories 13, 14 and 32: the panel is on screen for the whole loop, what it holds is decided
/// by the phase rather than by anything the learner can press, and once it opens it holds the
/// same sections in the same order every time so the learner learns where to look.
///
/// It takes the view model rather than a dozen separate values. It is not a reusable component
/// — it is the screen's other half, and every value it renders comes from one loop, so passing
/// them one by one would only be a longer way of saying the same thing that could fall out of
/// step. `@Observable` still narrows redraws to the properties actually read.
private struct FeedbackInspector: View {
    let viewModel: ExplainViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                header

                if let lockedMessage {
                    Text(lockedMessage)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    FeedbackPanel(
                        conceptName: viewModel.concept?.name ?? "",
                        outcome: viewModel.outcome,
                        prediction: viewModel.prediction,
                        expectedOutput: viewModel.expectedOutput ?? "",
                        feedback: viewModel.structuredFeedback,
                        noReadingExplanation: noReadingExplanation,
                        connections: viewModel.connectedConcepts
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.large)
        }
        .background(Theme.Color.windowBackground)
        .accessibilityLabel(viewModel.isFeedbackLocked ? "Feedback, locked" : "Feedback")
    }

    private var header: some View {
        Label {
            Text("Feedback")
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.primaryText)
        } icon: {
            Image(systemName: viewModel.isFeedbackLocked ? "lock.fill" : "lock.open.fill")
                .foregroundStyle(Theme.Color.secondaryText)
        }
    }

    /// Why there is no reading to show. Each reason says something different about what the
    /// learner should do next, so none of them is flattened into "unavailable".
    private var noReadingExplanation: String? {
        switch viewModel.generation {
        case .cancelled:
            "You stopped the question before it arrived, so there is no reading of your explanation. Nothing else in the loop is affected."
        case .unavailable(let availability):
            availability.message
        case .failed(let explanation):
            explanation
        case .idle, .running, .asked:
            nil
        }
    }

    /// Why the panel is shut, or `nil` once it is open — which is the same question as "is the
    /// panel open", asked of the same phase the lock icon reads. There is no message for the
    /// unlocked phases because there is nothing to explain: the panel itself is the answer.
    private var lockedMessage: String? {
        if viewModel.isGenerating {
            return "The model is reading your reasoning. The feedback stays locked until you have been asked about it and have answered."
        }

        switch viewModel.phase {
        case .prompt:
            return "Locked until you commit to an output and a reason. Working it out yourself is the part that does the learning."
        case .reveal:
            return "Locked until you have been asked about your reasoning and have answered."
        case .socratic:
            return "Answer the question or say you have nothing to add, and this unlocks."
        case .feedback, .committed:
            return nil
        }
    }
}

/// The unlocked panel: the fixed running order, written out once, in one sequence.
///
/// Driven by values rather than by the loop, so "the same sections in the same order every
/// time" is a property of one view that can be looked at in a preview, rather than a promise
/// spread across the screen. Only the misconception section is conditional, and it is absent
/// rather than empty — telling a learner about a wrong belief they did not show is worse than
/// saying nothing at all.
private struct FeedbackPanel: View {
    let conceptName: String
    let outcome: PredictionOutcome?
    let prediction: String
    let expectedOutput: String

    /// The model's reading, or `nil` when there was none to be had.
    let feedback: StructuredFeedback?

    /// Why there was none, shown in the reading's place so the order still holds.
    let noReadingExplanation: String?

    /// From the ontology, so this section survives having no model at all.
    let connections: [Concept]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            if let outcome {
                FeedbackSection(title: "What it printed") {
                    OutputComparison(
                        outcome: outcome,
                        prediction: prediction,
                        expectedOutput: expectedOutput
                    )
                }
            }

            modelReading

            FeedbackSection(title: "Connect this") {
                ConnectionList(conceptName: conceptName, connections: connections)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The model's half, and only the model's half, inside the one component that says so.
    ///
    /// The rubric wording and the correction are authored content, but *which* points it
    /// credits and *which* belief it names are the model's reading of what the learner wrote,
    /// and that is the thing they must never remember as their own conclusion.
    @ViewBuilder
    private var modelReading: some View {
        if let feedback {
            // The shared component, so the reading the learner sees now and the one they read
            // back from this note in the graph months later are the same rendering.
            ModelReadingCard(reading: feedback)
        } else if let noReadingExplanation {
            // The same slot, under the same heading, so the running order still holds when
            // there was no model. Not marked as the model's words, because there are none —
            // and not filed under "what you got right", which would put an explanation of the
            // model's absence under a heading claiming to list the learner's hits.
            FeedbackSection(title: ModelReadingCard.title) {
                Text(noReadingExplanation)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One heading and its contents. The panel's sections are all this shape, which is what keeps
/// them looking like one list rather than five separate designs.
private struct FeedbackSection<Content: View>: View {
    let title: String

    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text(title)
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.primaryText)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The prediction beside the real output, restated in the panel so the verdict and the
/// feedback on it can be read without looking away.
///
/// The prediction is the learner's own text and is presented plainly. Everything the model
/// produced sits below it inside a marked card, so the two never blur together.
private struct OutputComparison: View {
    let outcome: PredictionOutcome
    let prediction: String
    let expectedOutput: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Label {
                Text(verdict)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                OutcomeSymbol(outcome: outcome)
            }

            quoted("What you predicted", prediction)
            quoted("What it prints", expectedOutput)
        }
    }

    private func quoted(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)

            Text(text)
                .font(Theme.Font.code)
                .foregroundStyle(Theme.Color.primaryText)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.small)
                .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.small))
        }
        .accessibilityElement(children: .combine)
    }

    private var verdict: String {
        switch outcome {
        case .correct: "Your prediction matched."
        case .incorrect: "Your prediction did not match."
        }
    }
}

/// Story 31: the neighbours, with a prompt to think about the link rather than an explanation
/// of it. The link is the learner's to make — handing it over would be the same mistake the
/// Socratic question exists to avoid.
private struct ConnectionList: View {
    let conceptName: String
    let connections: [Concept]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            if connections.isEmpty {
                Text("Nothing in the ontology is authored as a neighbour of \(conceptName) yet.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Before you move on: how would you explain the link between \(conceptName) and each of these?")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(connections) { concept in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                        Text(concept.name)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.primaryText)

                        Text(concept.summary)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.small)
                    .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.small))
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Light") {
    ExplainScreen()
        .environment(Router())
        .environment(ContentService())
        .environment(SchedulingService.inMemory())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ExplainScreen()
        .environment(Router())
        .environment(ContentService())
        .environment(SchedulingService.inMemory())
        .preferredColorScheme(.dark)
}

#Preview("Feedback panel, light") {
    FeedbackPanel.preview
        .preferredColorScheme(.light)
}

#Preview("Feedback panel, dark") {
    FeedbackPanel.preview
        .preferredColorScheme(.dark)
}

private extension FeedbackPanel {

    /// The unlocked panel with every section populated, including the conditional one.
    ///
    /// Worth its own preview because the panel is only reachable at the end of a whole session
    /// and cannot be driven from a screen preview — and because the wash marking model-written
    /// text is a new authored colour that has to be checked in both appearances.
    static var preview: some View {
        let concept = Concept(
            id: "optionals",
            name: "Optionals",
            summary: "A value that may be absent.",
            position: ConceptPosition(x: 0.5, y: 0.5),
            prerequisites: ["variables"],
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

        return ScrollView {
            FeedbackPanel(
                conceptName: concept.name,
                outcome: .incorrect,
                prediction: "5",
                expectedOutput: "Optional(5)",
                feedback: StructuredFeedback(
                    concept: concept,
                    feedback: ExplanationFeedback(
                        socraticQuestion: "What told you the wrapper would be gone?",
                        coveredRubricPoints: [1],
                        misconceptions: [.printingShowsTheValue]
                    )
                ),
                noReadingExplanation: nil,
                connections: [
                    Concept(
                        id: "variables",
                        name: "Variables",
                        summary: "A name bound to a value, and whether that binding can change.",
                        position: ConceptPosition(x: 0.2, y: 0.5),
                        prerequisites: [],
                        related: [],
                        rubric: [],
                        misconceptions: []
                    )
                ]
            )
            .padding(Theme.Spacing.large)
        }
        .frame(width: Theme.Size.inspectorIdealWidth)
        .background(Theme.Color.windowBackground)
    }
}
