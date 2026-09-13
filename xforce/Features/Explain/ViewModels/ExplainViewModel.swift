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
/// The state machine runs end to end, `prompt` through `committed`. The panel's content is
/// built the moment the session's one inference returns and then withheld until the gate
/// opens — the staging the learner experiences is a display concern, not a second call.
@MainActor
@Observable
final class ExplainViewModel {

    private let content: ContentService
    private let feedback: any FeedbackService
    private let scheduling: SchedulingService

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

    /// The panel's content, built when the inference returns and held back until the gate
    /// opens. Read through ``structuredFeedback``, never directly.
    private var judged: StructuredFeedback?

    /// The in-flight inference. Kept so the learner can stop a slow one; a test borrows the
    /// same handle to await the call rather than polling for it.
    @ObservationIgnored private(set) var generationTask: Task<Void, Never>?

    /// Where the concept stands in the schedule once the session has been committed.
    private(set) var progress: ConceptProgress?

    /// The snippet the loop moves on to, chosen at commit so that what comes next is settled
    /// before the learner is asked to move on.
    private(set) var nextSnippet: Snippet?

    /// Why the commit could not be saved, or `nil`. Kept apart from ``state`` so that a store
    /// refusing a write does not replace the screen and take the unsaved session with it.
    private(set) var commitFailure: String?

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
    /// The commit reads it from here and writes it into the note: an answered response carries
    /// the text, a skip carries nothing, and `nil` means the question was never asked because
    /// the model could not be reached.
    private(set) var socraticResponse: SocraticResponse?

    private var writtenExplanation = ""

    @ObservationIgnored private var hasPrewarmed = false

    init(content: ContentService, feedback: any FeedbackService, scheduling: SchedulingService) {
        self.content = content
        self.feedback = feedback
        self.scheduling = scheduling
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

    /// The feedback panel's content, or `nil` while the gate is shut.
    ///
    /// Derived from the phase for the same reason ``expectedOutput`` is: there is no property
    /// a view could read to open the panel early, so the gate cannot be circumvented by a
    /// control that forgets to check it. The content itself has existed since the inference
    /// returned — withholding it is the whole staging the learner experiences.
    var structuredFeedback: StructuredFeedback? {
        phase.isFeedbackUnlocked ? judged : nil
    }

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

    /// Whether the session can be written down.
    ///
    /// Not before `feedback`. Committing jumps the loop past every phase between here and
    /// there, so a commit offered at the reveal would be a way around the question — the one
    /// thing the gate exists to prevent. Every degradation path still reaches `feedback`: an
    /// unavailable model, a failed generation and a cancelled one all unlock it carrying their
    /// reason, so nobody is stranded short of the commit.
    var canCommit: Bool {
        phase >= .feedback && phase < .committed && snippet != nil
    }

    /// Puts the learner on a snippet. A loop that has already moved past `prompt` is left
    /// alone, so a re-entered screen never rewinds work in progress.
    func load() {
        guard phase == .prompt else { return }

        if let failure = content.failure {
            state = .failed(failure.message)
            return
        }

        let seen: [String: Date]
        do {
            seen = try scheduling.seenSnippets()
        } catch {
            state = .failed(Self.storeUnreadableMessage)
            return
        }

        guard let snippet = content.nextSnippet(seen: seen) else {
            state = .failed(ContentError.empty.message)
            return
        }

        show(snippet)
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

        // Unreachable while the content service refuses a snippet naming a concept that
        // does not exist, but it still unlocks rather than returning: no path may leave the
        // learner stranded at `reveal` with nothing to press.
        guard let concept, let snippet else {
            generation = .failed(FeedbackError.unavailable(availability).message)
            advance(to: .feedback)
            return
        }

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
                judged = StructuredFeedback(
                    concept: concept,
                    feedback: result,
                    ontology: content.concepts
                )
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

    /// Writes the session down and moves the concept through the schedule.
    ///
    /// The note is immutable, so this is the only moment the learner's prediction and reasoning
    /// are captured — and it happens once. A second call is refused by the forward-only rule,
    /// which is what keeps one commit to one note.
    func commit() {
        guard canCommit, let snippet, let outcome else { return }

        // Read from what was judged rather than from what the model said, so a misconception
        // belonging to another concept cannot reach the schedule after being filtered out of
        // the panel. A session with no model to ask judged nothing, which grades as clean.
        let note = Note(
            conceptID: snippet.conceptID,
            snippetID: snippet.id,
            prediction: prediction,
            explanation: explanation,
            socraticQuestion: socraticQuestion,
            socraticAnswer: socraticResponse?.storedAnswer,
            coveredRubricPoints: judged?.covered.map(\.number) ?? [],
            detectedMisconceptionIDs: judged?.misconceptions.map(\.id) ?? [],
            outcome: outcome.sessionOutcome(misconceptionDetected: judged?.hasMisconception == true)
        )

        do {
            progress = try scheduling.record(note)
        } catch {
            commitFailure = Self.storeUnwritableMessage
            return
        }

        // Saved. Nothing from here may report the commit as failed, or the learner would
        // write the same session down twice.
        commitFailure = nil
        nextSnippet = (try? scheduling.seenSnippets()).flatMap(content.nextSnippet(seen:))
        advance(to: .committed)
    }

    /// Begins a fresh pass on the snippet the commit chose.
    ///
    /// The forward-only rule governs one pass through the loop, and a committed session is the
    /// end of one. This is the only place a new pass begins, and therefore the only place that
    /// sets the phase without going through ``advance(to:)``.
    func startNextSnippet() {
        guard phase == .committed, let nextSnippet else { return }

        show(nextSnippet)
        prediction = ""
        writtenExplanation = ""
        socraticAnswer = ""
        socraticResponse = nil
        generation = .idle
        generationTask = nil
        judged = nil
        diff = nil
        outcome = nil
        progress = nil
        self.nextSnippet = nil
        commitFailure = nil
        phase = .prompt
    }

    /// The only way the phase changes within one pass. A transition that does not advance is
    /// refused, which is what makes the loop forward-only.
    private func advance(to next: LoopPhase) {
        guard next > phase else { return }
        phase = next
    }

    private func show(_ snippet: Snippet) {
        self.snippet = snippet
        concept = content.concept(withID: snippet.conceptID)
    }

    /// The store holds the only copy of the learner's work, so neither failure is allowed to
    /// pass as though the session had been saved.
    private static let storeUnreadableMessage =
        "Your notes and progress could not be read, so there is nothing to practise against."

    private static let storeUnwritableMessage =
        "This session could not be saved. Nothing has been lost — try committing it again."
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
