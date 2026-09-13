//
//  FakeFeedbackService.swift
//  xforceTests
//

import Foundation
import Synchronization
@testable import xforce

/// The second conformance the feedback protocol exists for.
///
/// The app ships exactly one conformance, backed by the on-device model. This is the other
/// one, and it is what justifies the only protocol in the project: a test cannot drive the
/// real model, cannot make it unavailable on demand, and cannot make it hang.
///
/// It records what it was asked so a suite can assert that a session made **exactly one**
/// inference, and it can be told to answer, to fail, or to hang so every path through the
/// gate has something concrete to exercise.
final class FakeFeedbackService: FeedbackService {

    /// What the one inference does when it is asked for.
    enum Behaviour: Sendable {

        /// Returns this question.
        case answers(String)

        /// Throws this error instead of answering.
        case fails(FeedbackError)

        /// Never returns on its own. Only cancellation ends it.
        case hangs
    }

    /// What the service was asked to do, so a test can assert on the call itself rather
    /// than only on what the view model did with the result.
    struct Calls: Sendable {
        var prewarms = 0
        var inferences = 0
        var lastExplanation: String?
        var lastConceptID: String?
        var lastSnippetID: String?
    }

    let availability: FeedbackAvailability

    private let behaviour: Behaviour
    private let recorded = Mutex(Calls())

    init(
        availability: FeedbackAvailability = .available,
        behaviour: Behaviour = .answers(FakeFeedbackService.defaultQuestion)
    ) {
        self.availability = availability
        self.behaviour = behaviour
    }

    /// A question that reads like one: it asks about the reasoning and corrects nothing.
    static let defaultQuestion = "What would this print if the value were nil instead?"

    var calls: Calls { recorded.withLock { $0 } }

    func prewarm() {
        recorded.withLock { $0.prewarms += 1 }
    }

    func feedback(
        concept: Concept,
        snippet: Snippet,
        explanation: String
    ) async throws -> ExplanationFeedback {
        recorded.withLock {
            $0.inferences += 1
            $0.lastExplanation = explanation
            $0.lastConceptID = concept.id
            $0.lastSnippetID = snippet.id
        }

        switch behaviour {
        case .answers(let question):
            return ExplanationFeedback(socraticQuestion: question)

        case .fails(let error):
            throw error

        case .hangs:
            // Long enough that only cancellation can end it.
            try await Task.sleep(for: .seconds(3600))
            throw CancellationError()
        }
    }
}
