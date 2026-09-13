//
//  FeedbackGeneration.swift
//  xforce
//

import Foundation

/// How the session's one inference is going.
///
/// Separate from ``ViewState``, which is about whether the screen has a snippet to show.
/// This is about the half of the screen that needs a model, and it is what lets an
/// unavailable model disable that half and explain itself instead of failing the screen.
///
/// Every case except ``running`` is terminal: there is one inference per session, so there
/// is nothing to retry into.
nonisolated enum FeedbackGeneration: Hashable, Sendable {

    /// Nothing has been asked for. The learner is still writing.
    case idle

    /// The one inference is in flight.
    case running

    /// The model asked its question.
    case asked(String)

    /// The learner stopped a slow generation rather than wait for it.
    case cancelled

    /// The model was never asked, for this reason.
    case unavailable(FeedbackAvailability)

    /// The model was asked and could not answer. Carries what to tell the learner.
    case failed(String)

    /// The question, when there is one.
    var question: String? {
        if case .asked(let question) = self { question } else { nil }
    }

    var isRunning: Bool { self == .running }
}
