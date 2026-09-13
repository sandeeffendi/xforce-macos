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
            return ExplanationFeedback(
                socraticQuestion: response.content.socraticQuestion,
                coveredRubricPoints: response.content.coveredRubricPoints,
                misconceptions: response.content.misconceptions
            )
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

    /// The three jobs, and the prohibition that matters more than any of them.
    ///
    /// Stated as a prohibition as much as an instruction, because a model that answers instead
    /// of asking would hand the learner the reasoning the whole loop exists to make them do
    /// themselves. The judging half is bounded by the schema rather than by prose: the model
    /// picks numbers from a list it is given and cases from a set it cannot add to.
    private static let instructions = """
        You are a Socratic tutor for someone learning Swift. You will be given a snippet, \
        what it really prints, a beginner's explanation of why it prints that, a numbered \
        rubric for the concept, and a list of misconceptions that concept is known for.

        Do three things, and nothing else.

        1. Ask exactly one short question about their explanation. Never correct them, never \
        state the right answer, never name their mistake, and never explain the code yourself. \
        Ask about the reasoning they gave: what it rests on, or what it would predict under a \
        small change to the snippet. If their explanation is sound, ask a question that tests \
        whether it generalises. Address them as "you" and keep it to one sentence.

        2. List the numbers of the rubric points their explanation actually covered. Judge \
        only what they wrote, not what they might have meant, and not whether their prediction \
        was right. Use only numbers from the rubric you were given. List nothing if they \
        covered nothing.

        3. List the misconceptions their explanation actually shows. Only report one you can \
        point at a specific part of what they wrote. Report none if none is there — a learner \
        told about a wrong belief they do not hold is worse off than one told nothing.
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

        Rubric for this concept, numbered:
        \(numberedRubric(concept))

        Misconceptions this concept is known for:
        \(misconceptionCatalogue(concept))

        The learner's explanation of why it prints that:
        \(explanation)
        """
    }

    /// The numbered list the covered points are reported against. Supplying it in the prompt is
    /// what makes the answer a set of integers, and integers are what let the complement be
    /// computed in Swift and a regression assertion be a set comparison.
    private static func numberedRubric(_ concept: Concept) -> String {
        concept.rubric
            .map { "\($0.number). \($0.text)" }
            .joined(separator: "\n")
    }

    /// The concept's own misconceptions, named by the same ids the generated type is closed
    /// over. The schema already makes an invented label impossible; this makes an irrelevant
    /// one unlikely, and Swift discards any that still arrive.
    private static func misconceptionCatalogue(_ concept: Concept) -> String {
        concept.misconceptions
            .map { "- \($0.id): \($0.name)" }
            .joined(separator: "\n")
    }
}

/// The shape the model is constrained to produce.
///
/// Deliberately small, and every field here is something only a model can do. Guided
/// generation earns its place three times over: a free-form response could answer rather than
/// ask, a free-form rubric judgement could not be compared as a set of integers, and a
/// free-form misconception label could name a wrong belief the ontology has never heard of.
///
/// What is *not* here matters as much. The missing rubric points are absent because they are
/// the complement of ``coveredRubricPoints`` and computing them keeps the two lists from
/// contradicting each other. The connected concepts are absent because the ontology already
/// authors them.
@Generable
private nonisolated struct GeneratedFeedback {

    @Guide(description: "One question that makes the learner re-examine their own reasoning. Never a correction, never the answer.")
    let socraticQuestion: String

    @Guide(description: "Numbers of the rubric points the learner's explanation covered")
    let coveredRubricPoints: [Int]

    @Guide(description: "Misconceptions detected in the learner's explanation")
    let misconceptions: [MisconceptionID]
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
