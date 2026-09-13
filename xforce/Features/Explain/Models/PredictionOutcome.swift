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
