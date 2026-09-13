//
//  PredictionOutcome.swift
//  xforce
//

import Foundation

/// Whether the learner's prediction matched what the snippet prints.
///
/// Two cases, and deliberately still two now that misconceptions can be detected. This is the
/// output comparison and nothing else — it is stated to the learner at the reveal, before any
/// model has finished reading, and a value that could change underneath them afterwards would
/// make the reveal a draft rather than a verdict. What a detected misconception changes is the
/// *session* outcome, which is a separate question answered below.
nonisolated enum PredictionOutcome: Hashable, Sendable {
    case correct
    case incorrect
}

extension PredictionOutcome {

    /// What the Leitner schedule acts on.
    ///
    /// **The model can never cause `failed`.** That is not a convention here, it is the shape
    /// of the function: `failed` is returned only on the `incorrect` branch, which the
    /// misconception flag cannot reach. The most the model can ever do is move a correct
    /// prediction between `mastered` and `fragile`, which holds the concept in its box rather
    /// than sending it back to the start.
    ///
    /// - Parameter misconceptionDetected: whether the panel found a misconception belonging to
    ///   this concept. False whenever there was no model to ask, so a Mac with no Apple
    ///   Intelligence grades exactly as a clean session does.
    func sessionOutcome(misconceptionDetected: Bool) -> SessionOutcome {
        switch self {
        case .correct: misconceptionDetected ? .fragile : .mastered
        case .incorrect: .failed
        }
    }
}
