//
//  PredictionOutcome.swift
//  xforce
//

import Foundation

/// Whether the learner's prediction matched what the snippet prints.
///
/// Two cases for now. The outcome that distinguishes a correct prediction carrying a detected
/// misconception from a clean one arrives with the feedback slice, which is the first thing
/// able to detect a misconception at all.
nonisolated enum PredictionOutcome: Hashable, Sendable {
    case correct
    case incorrect
}

extension PredictionOutcome {

    /// What the Leitner schedule acts on.
    ///
    /// A wrong prediction is always `failed`, and no model can ever cause that. Until
    /// misconception detection arrives with the feedback slice, a correct prediction is always
    /// `mastered`: `fragile` is the case a detected misconception will select, and nothing in
    /// the app can detect one yet.
    var sessionOutcome: SessionOutcome {
        switch self {
        case .correct: .mastered
        case .incorrect: .failed
        }
    }
}
