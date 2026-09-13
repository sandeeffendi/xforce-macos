//
//  OnDeviceFeedbackService.swift
//  xforce
//

import Foundation
import FoundationModels

/// The shipped conformance: Apple's on-device model, asked once per session.
///
/// An `actor` because the isolation is the requirement. The app builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so a class here would put generation on the
/// main actor and stall the window while the model reads. An actor gives the work its own
/// executor, and `respond` is `nonisolated(nonsending)`, so it runs in this actor's context
/// rather than hopping back to the caller's.
///
/// Cancellation needs nothing of its own: the call inherits the cancellation of whichever
/// task awaits it, and the view model owns that task.
actor OnDeviceFeedbackService: FeedbackService {

    private let model = SystemLanguageModel.default

    /// The session ``prewarm()`` warmed, waiting to be spent.
    ///
    /// A session is consumed by the inference it carries rather than kept, because a session
    /// retains its transcript: reusing one across loops would grow the context with every
    /// session the learner completed until it overflowed mid-answer.
    private var warmed: LanguageModelSession?

    /// Reads straight from the system model, so a Mac that becomes eligible mid-launch is
    /// not stuck with a stale answer. `SystemLanguageModel` is `Sendable`, which is what
    /// lets this be read without hopping onto the actor.
    nonisolated var availability: FeedbackAvailability {
        FeedbackAvailability(model.availability)
    }

    nonisolated func prewarm() {
        Task { await warmUp() }
    }

    func feedback(
        concept: Concept,
        snippet: Snippet,
        explanation: String
    ) async throws -> ExplanationFeedback {
        let availability = availability
        guard availability.isAvailable else {
            throw FeedbackError.unavailable(availability)
        }

        let session = takeSession()

        do {
            let response = try await session.respond(
                to: Self.prompt(concept: concept, snippet: snippet, explanation: explanation),
                generating: GeneratedFeedback.self
            )
            return ExplanationFeedback(socraticQuestion: response.content.socraticQuestion)
        } catch let error as LanguageModelSession.GenerationError {
            throw FeedbackError(error)
        }
    }

    private func warmUp() {
        guard availability.isAvailable else { return }

        let session = warmed ?? Self.makeSession()
        warmed = session
        session.prewarm()
    }

    /// Hands over the warmed session and lets go of it, so the next session starts clean.
    private func takeSession() -> LanguageModelSession {
        defer { warmed = nil }
        return warmed ?? Self.makeSession()
    }

    private static func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: instructions)
    }

    /// The one thing the model is for. Stated as a prohibition as much as an instruction,
    /// because a model that answers instead of asking would hand the learner the reasoning
    /// the whole loop exists to make them do themselves.
    private static let instructions = """
        You are a Socratic tutor for someone learning Swift. You will be given a snippet, \
        what it really prints, and a beginner's explanation of why it prints that.

        Ask exactly one short question about their explanation.

        Never correct them. Never state the right answer, name their mistake, or explain the \
        code yourself. Ask about the reasoning they gave: what it rests on, or what it would \
        predict under a small change to the snippet. If their explanation is sound, ask a \
        question that tests whether it generalises. Address them as "you" and keep it to one \
        sentence.
        """

    private static func prompt(
        concept: Concept,
        snippet: Snippet,
        explanation: String
    ) -> String {
        """
        Concept: \(concept.name)
        \(concept.summary)

        Snippet:
        \(snippet.code)

        What it really prints:
        \(snippet.expectedOutput)

        The learner's explanation of why it prints that:
        \(explanation)
        """
    }
}

/// The shape the model is constrained to produce.
///
/// Deliberately small: one field in this slice. Guided generation earns its place here
/// because a free-form response could answer rather than ask, and because the rubric numbers
/// and the misconception cases that join this type later are exactly the kind of closed set
/// a schema can enforce and prose cannot.
@Generable
private nonisolated struct GeneratedFeedback {

    @Guide(description: "One question that makes the learner re-examine their own reasoning. Never a correction, never the answer.")
    let socraticQuestion: String
}

private extension FeedbackAvailability {

    nonisolated init(_ availability: SystemLanguageModel.Availability) {
        switch availability {
        case .available:
            self = .available
        case .unavailable(.deviceNotEligible):
            self = .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            self = .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            self = .modelNotReady
        case .unavailable:
            // A reason added after this was written. Treated as not ready, which is the
            // only one of the three that tells the learner to wait rather than to act.
            self = .modelNotReady
        }
    }
}

private extension FeedbackError {

    /// Context-window overflow is the one generation failure the learner can do something
    /// about, so it is the one that gets its own case. The rest keep the framework's own
    /// description rather than being flattened into "something went wrong".
    nonisolated init(_ error: LanguageModelSession.GenerationError) {
        switch error {
        case .exceededContextWindowSize:
            self = .explanationTooLong
        default:
            self = .generationFailed(error.localizedDescription)
        }
    }
}
