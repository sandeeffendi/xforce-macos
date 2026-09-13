//
//  ExplainViewModel.swift
//  xforce
//

import Foundation
import Observation

/// Drives one pass through the explanation loop.
///
/// The learner is shown a snippet and must commit to what it prints and why before anything
/// is revealed. Nothing here executes Swift: the ground truth is the snippet's authored
/// `expectedOutput`.
///
/// This slice covers the first two phases, `prompt` and `reveal`. The Socratic question, the
/// structured feedback and the commit arrive in later slices and extend the same state
/// machine rather than replacing it.
@MainActor
@Observable
final class ExplainViewModel {

    private let content: ContentService

    private(set) var state: ViewState = .idle
    private(set) var phase: LoopPhase = .prompt

    private(set) var snippet: Snippet?
    private(set) var concept: Concept?

    private(set) var diff: OutputDiff?
    private(set) var outcome: PredictionOutcome?

    /// What the learner thinks the snippet prints, verbatim.
    var prediction = ""

    /// Why they think so, in their own words.
    var explanation = ""

    init(content: ContentService) {
        self.content = content
    }

    /// The snippet's real output, withheld until the reveal.
    ///
    /// Deriving this from the phase rather than exposing the snippet's `expectedOutput`
    /// directly is what keeps the gate structural: there is no property a view could read to
    /// show the answer early.
    var expectedOutput: String? {
        phase >= .reveal ? snippet?.expectedOutput : nil
    }

    /// Both fields must carry something before the loop will move.
    var canSubmit: Bool {
        phase == .prompt
            && snippet != nil
            && prediction.hasContent
            && explanation.hasContent
    }

    var isFeedbackLocked: Bool { phase.isFeedbackUnlocked == false }

    /// Puts the learner on a snippet. A loop that has already moved past `prompt` is left
    /// alone, so a re-entered screen never rewinds work in progress.
    func load() {
        guard phase == .prompt else { return }

        if let failure = content.failure {
            state = .failed(failure.message)
            return
        }

        guard let snippet = content.firstSnippet else {
            state = .failed(ContentError.empty.message)
            return
        }

        self.snippet = snippet
        concept = content.concept(withID: snippet.conceptID)
        state = .loaded
    }

    /// Commits the prediction and reveals the ground truth.
    func submit() {
        guard canSubmit, let snippet else { return }

        let diff = OutputDiff.comparing(prediction: prediction, expected: snippet.expectedOutput)
        self.diff = diff
        outcome = diff.isCorrect ? .correct : .incorrect

        advance(to: .reveal)
    }

    /// The only way the phase changes. A transition that does not advance is refused, which
    /// is what makes the loop forward-only.
    private func advance(to next: LoopPhase) {
        guard next > phase else { return }
        phase = next
    }
}

private extension String {
    /// Whitespace alone is not an answer.
    var hasContent: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
