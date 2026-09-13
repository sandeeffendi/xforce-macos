//
//  FeedbackService.swift
//  xforce
//

import Foundation

/// Whether the on-device model can be used, and when it cannot, why not.
///
/// Availability is a value the practice screen renders, not an error path. The prompt,
/// reveal, grading and commit halves of the loop need no model at all, so an unavailable
/// model disables part of one screen and explains itself rather than blocking the app.
///
/// Each reason carries its own message because "unavailable" on its own leaves the learner
/// guessing which of three quite different things to do about it.
nonisolated enum FeedbackAvailability: Hashable, Sendable {

    /// The model is there and can be asked.
    case available

    /// This Mac cannot run Apple Intelligence at all.
    case deviceNotEligible

    /// The Mac could, but Apple Intelligence is switched off.
    case appleIntelligenceNotEnabled

    /// Apple Intelligence is on, but the model has not finished downloading.
    case modelNotReady

    var isAvailable: Bool { self == .available }

    /// What to tell the learner, or `nil` when there is nothing to explain.
    var message: String? {
        switch self {
        case .available:
            nil
        case .deviceNotEligible:
            """
            This Mac is not eligible for Apple Intelligence, so there is no question to ask \
            about your reasoning. Everything else — the prediction, the real output and your \
            record of the session — works exactly as it does anywhere else.
            """
        case .appleIntelligenceNotEnabled:
            """
            Apple Intelligence is switched off. Turn it on in System Settings to be asked \
            about your reasoning. The rest of the loop does not need it.
            """
        case .modelNotReady:
            """
            The on-device model is still downloading. Nothing is broken, and the rest of \
            the loop is unaffected — start another session once the download has finished \
            and you will be asked about your reasoning.
            """
        }
    }
}

/// Why one attempt at feedback did not produce any.
///
/// Specific and `Equatable` rather than one opaque failure, for the same reason
/// ``ContentError`` is: a test asserts that a particular condition produced a particular
/// explanation, not merely that something went wrong.
///
/// Cancellation is deliberately absent. A learner stopping a slow generation is not a
/// failure, so it stays a `CancellationError` and is handled where the loop is driven.
nonisolated enum FeedbackError: Error, Equatable {

    /// The model was asked while it could not be used.
    case unavailable(FeedbackAvailability)

    /// The learner's text did not fit in the model's context window.
    case explanationTooLong

    /// Anything else the model reported, kept for the message it came with.
    case generationFailed(String)

    /// What the learner is told. Overflow says the text is too long, because that is
    /// something they can act on; a generic failure would leave them retyping the same
    /// explanation and getting the same result.
    var message: String {
        switch self {
        case .unavailable(let availability):
            availability.message ?? "The on-device model could not be reached."
        case .explanationTooLong:
            """
            Your explanation is too long for the on-device model to read in one go. A \
            shorter version of the same reasoning will get a question back.
            """
        case .generationFailed(let detail):
            "The model could not finish reading your explanation: \(detail)"
        }
    }
}

/// One inference's worth of feedback on a session.
///
/// The question and the judgement arrive together, from one call, rather than from two: a
/// language model session carries its transcript forward, so a second call would resend the
/// first call and its output and push the total past the context window. The staging the
/// learner experiences is a display concern, handled by the view model withholding what it
/// already holds.
///
/// This is the model's raw answer, not the panel's content. It is deliberately the smallest
/// shape that lets the panel be built: the missing rubric points are computed from
/// ``coveredRubricPoints`` in Swift, and the connected concepts are read from the ontology and
/// never asked for at all.
nonisolated struct ExplanationFeedback: Hashable, Sendable {

    /// A question about the learner's reasoning. Never a correction.
    let socraticQuestion: String

    /// The numbers of the rubric points the model judged the explanation to have covered,
    /// against the numbered list it was given in the prompt.
    ///
    /// Only the covered ones. Asking for the missing ones too would let the two lists overlap,
    /// and the panel could then show one point under both headings; computing the complement
    /// makes the two sections consistent by construction. Numbers outside the concept's rubric
    /// are discarded where the panel is built, not here — this type records what the model
    /// said, including when what it said was nonsense.
    let coveredRubricPoints: [Int]

    /// The misconceptions the model detected, drawn from a closed set it cannot add to.
    ///
    /// Still filtered afterwards: the set is closed over the whole ontology, so a case that
    /// belongs to some other concept has to be discarded before the learner sees it.
    let misconceptions: [MisconceptionID]

    /// Defaults for the two judged fields, so a caller that only cares about the question —
    /// a preview, or a test of the gate — does not have to say "nothing" twice.
    init(
        socraticQuestion: String,
        coveredRubricPoints: [Int] = [],
        misconceptions: [MisconceptionID] = []
    ) {
        self.socraticQuestion = socraticQuestion
        self.coveredRubricPoints = coveredRubricPoints
        self.misconceptions = misconceptions
    }
}

/// Produces the model's half of the explanation loop.
///
/// **The only protocol in the app.** The working agreement rules out protocols with a single
/// conformance, and the second conformance is what justifies this one: tests cannot drive the
/// real model, cannot make it unavailable on demand, and cannot make it hang long enough to
/// be cancelled. The shipped app has exactly one conformance; the fake lives in the test
/// target and is never built into the product.
///
/// `nonisolated` and `Sendable` because the point of the seam is that generation happens off
/// the main actor. The conformance decides where its work runs; the view model only awaits it.
nonisolated protocol FeedbackService: Sendable {

    /// Whether the model can be asked, checked once and rendered as a value.
    var availability: FeedbackAvailability { get }

    /// Warms the model up before it is needed, so the wait lands while the learner is still
    /// typing rather than after they submit. Cheap to call and safe to call more than once.
    func prewarm()

    /// The single inference of a session.
    ///
    /// The learner's Socratic answer is deliberately not a parameter: nothing the model
    /// produces depends on it, which is what keeps the recorded answer uncontaminated by a
    /// feedback loop.
    ///
    /// - Throws: ``FeedbackError`` for anything the learner can be told about, and
    ///   `CancellationError` when the task carrying the call is cancelled.
    func feedback(
        concept: Concept,
        snippet: Snippet,
        explanation: String
    ) async throws -> ExplanationFeedback
}
