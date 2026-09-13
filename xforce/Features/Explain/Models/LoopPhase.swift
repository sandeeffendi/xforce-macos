//
//  LoopPhase.swift
//  xforce
//

import Foundation

/// How far the learner has moved through the explanation loop.
///
/// Screen-specific, so it lives in the feature rather than in `Core`. Transitions only ever
/// move forward: there is no bypass, no setting that disables the gate, and no skip from
/// `prompt`. `Comparable` is what enforces that — a transition is refused unless it advances.
///
/// This slice implements `prompt` and `reveal`. The later phases are declared here because
/// the ordering is the mechanism, and a phase that appears later cannot be inserted without
/// re-deciding what "forward" means.
nonisolated enum LoopPhase: Int, Comparable, Sendable {

    /// Both fields open, feedback panel locked.
    case prompt

    /// Ground truth shown, outcome known, no AI output yet.
    case reveal

    /// One question visible, feedback still withheld.
    case socratic

    /// Full structured panel unlocked.
    case feedback

    /// Note written, progress updated.
    case committed

    static func < (lhs: LoopPhase, rhs: LoopPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The single derived property the feedback panel's presentation hangs off, so the gate
    /// cannot be circumvented by a stray control.
    var isFeedbackUnlocked: Bool { self >= .feedback }
}
