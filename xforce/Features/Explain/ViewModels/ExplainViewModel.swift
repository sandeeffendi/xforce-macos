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
/// This slice covers `prompt` through `feedback`. Writing the note and updating the schedule
/// — the `committed` phase — arrives in a later slice and extends the same state machine
/// rather than replacing it.
@MainActor
@Observable
final class ExplainViewModel {

    private let content: ContentService
    private let feedback: any FeedbackService

    private(set) var state: ViewState = .idle
    private(set) var phase: LoopPhase = .prompt

    private(set) var snippet: Snippet?
    private(set) var concept: Concept?

    private(set) var diff: OutputDiff?
    private(set) var outcome: PredictionOutcome?

    /// Whether the model can be asked at all, checked once when the screen is built.
    ///
    /// Held as a value rather than consulted at each use so the screen renders one settled
    /// answer, and so the reason can be shown in the place the question would have been.
    private(set) var availability: FeedbackAvailability

    /// How the session's one inference is going.
    private(set) var generation: FeedbackGeneration = .idle

    /// The in-flight inference. Kept so the learner can stop a slow one; a test borrows the
    /// same handle to await the call rather than polling for it.
    @ObservationIgnored private(set) var generationTask: Task<Void, Never>?

    /// What the learner thinks the snippet prints, verbatim.
    var prediction = ""

    /// Why they think so, in their own words.
    ///
    /// Writing to this warms the model up. Prewarming belongs on the keystroke rather than
    /// on submit because that is the only moment where the wait is free: the learner is
    /// still typing, and by the time they commit the model is ready.
    var explanation: String {
        get { writtenExplanation }
        set {
            writtenExplanation = newValue
            prewarmIfNeeded()
        }
    }

    /// What the learner says back to the question they were asked.
    var socraticAnswer = ""

    /// What they did with the question, once they have done it.
    ///
    /// Kept in view-model state for now. Storing it against the session is the commit
    /// slice's territory, and this is the seam it reads from: an answered response carries
    /// the text, a skip carries nothing, and `nil` here means the question was never asked
    /// because the model could not be reached.
    private(set) var socraticResponse: SocraticResponse?

    private var writtenExplanation = ""

    @ObservationIgnored private var hasPrewarmed = false

    init(content: ContentService, feedback: any FeedbackService) {
        self.content = content
        self.feedback = feedback
        availability = feedback.availability
    }

    /// The snippet's real output, withheld until the reveal.
    ///
    /// Deriving this from the phase rather than exposing the snippet's `expectedOutput`
    /// directly is what keeps the gate structural: there is no property a view could read to
    /// show the answer early.
    var expectedOutput: String? {
        phase >= .reveal ? snippet?.expectedOutput : nil
    }

    /// The question the model asked, when it managed to ask one.
    var socraticQuestion: String? { generation.question }

    /// Whether the model is working, so a pause does not read as a freeze.
    var isGenerating: Bool { generation.isRunning }

    /// Both fields must carry something before the loop will move.
    var canSubmit: Bool {
        phase == .prompt
            && snippet != nil
            && prediction.hasContent
            && explanation.hasContent
    }

    /// Whether the inspector is on screen at all.
    ///
    /// It is there for the whole loop once there is something to practise, because the lock
    /// has to be *seen* to read as intentional — a panel that simply has not appeared yet
    /// teaches the learner nothing about why they cannot have it.
    var isInspectorVisible: Bool { state == .loaded }

    /// The gate itself, derived from the phase and from nothing else. Every control that
    /// could otherwise have been disabled one by one hangs off this single value.
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

    /// Commits the prediction, reveals the ground truth, and asks the model its one question.
    func submit() {
        guard canSubmit, let snippet else { return }

        let diff = OutputDiff.comparing(prediction: prediction, expected: snippet.expectedOutput)
        self.diff = diff
        outcome = diff.isCorrect ? .correct : .incorrect

        advance(to: .reveal)
        ask()
    }

    /// Records what the learner wrote back and unlocks the feedback.
    ///
    /// An empty field is still an answer. It is recorded as one, distinct from a skip,
    /// because "wrote nothing" and "declined to write" are different things to know about
    /// someone's thinking later.
    func answer() {
        record(.answered(socraticAnswer.trimmed))
    }

    /// Records that the learner had nothing to add, and unlocks the feedback.
    func skip() {
        record(.skipped)
    }

    /// Stops a slow generation. The loop moves on rather than stranding the learner short of
    /// the commit, because there is one inference per session and so nothing to retry into.
    func cancelGenerating() {
        guard generation.isRunning else { return }

        generationTask?.cancel()
        generation = .cancelled
        advance(to: .feedback)
    }

    /// The session's single inference.
    ///
    /// When there is no model to ask, the loop moves straight to `feedback` carrying the
    /// reason. The panel it unlocks holds an explanation rather than feedback, which is the
    /// point: an unavailable model disables half of one screen, it does not strand the
    /// learner before the commit.
    private func ask() {
        guard availability.isAvailable else {
            generation = .unavailable(availability)
            advance(to: .feedback)
            return
        }

        guard let concept, let snippet else { return }
        let explanation = writtenExplanation

        generation = .running
        generationTask = Task {
            do {
                let result = try await feedback.feedback(
                    concept: concept,
                    snippet: snippet,
                    explanation: explanation
                )
                guard Task.isCancelled == false else { return }
                generation = .asked(result.socraticQuestion)
                advance(to: .socratic)
            } catch is CancellationError {
                // The learner stopped it. `cancelGenerating` already recorded that.
            } catch let error as FeedbackError {
                guard Task.isCancelled == false else { return }
                settle(on: error)
            } catch {
                guard Task.isCancelled == false else { return }
                settle(on: .generationFailed(error.localizedDescription))
            }
        }
    }

    /// A failed inference still has to let the loop reach the commit, so it unlocks the
    /// panel and puts its explanation where the question would have been.
    private func settle(on error: FeedbackError) {
        generation = .failed(error.message)
        advance(to: .feedback)
    }

    private func record(_ response: SocraticResponse) {
        guard phase == .socratic, socraticResponse == nil else { return }

        socraticResponse = response
        advance(to: .feedback)
    }

    /// Warms the model once, while the learner is still writing and only when there is a
    /// model to warm.
    private func prewarmIfNeeded() {
        guard hasPrewarmed == false, phase == .prompt, availability.isAvailable else { return }

        hasPrewarmed = true
        feedback.prewarm()
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

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
