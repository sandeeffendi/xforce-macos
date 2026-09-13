//
//  StructuredFeedback.swift
//  xforce
//

import Foundation

/// What one inference says about one explanation, once the model's answer has been made safe.
///
/// Built the moment the inference returns and then only rendered, which is what lets the panel
/// show the same sections in the same order every time: the sections are fields on a value,
/// not decisions taken while drawing.
///
/// Everything the model contributed is constrained before it lands here:
///
/// - ``covered`` is the model's numbers **intersected with** the concept's own rubric, so a
///   number the rubric does not have simply has nothing to match and disappears.
/// - ``missing`` is the complement of ``covered`` over that same rubric, computed here. The
///   two lists therefore partition the rubric exactly once and cannot contradict each other —
///   asking the model for both is what would have made that possible.
/// - ``misconceptions`` is the model's closed-set answer filtered down to the ones this
///   concept actually owns.
///
/// The concepts this one connects to are deliberately **not** here. They owe the model nothing
/// at all, so they are not carried by the type that exists to make the model's answer safe;
/// the view model reads them straight from the ontology, and they survive on a Mac that has no
/// model to ask.
nonisolated struct StructuredFeedback: Hashable, Sendable {

    /// The rubric points the explanation covered, in authored order.
    let covered: [RubricPoint]

    /// The rest of the rubric — computed, never generated.
    let missing: [RubricPoint]

    /// The detected misconceptions that belong to this concept, each carrying its correction.
    /// Empty when none was detected, which is what hides the section.
    let misconceptions: [Misconception]

    /// Makes one inference safe to show.
    ///
    /// - Parameters:
    ///   - concept: the concept being practised; its rubric and misconception list are the
    ///     only things the model's answer is allowed to select from.
    ///   - feedback: what the model said, unfiltered.
    init(concept: Concept, feedback: ExplanationFeedback) {
        let claimed = Set(feedback.coveredRubricPoints)

        // Intersecting with the authored rubric is what discards an out-of-range number: there
        // is no point to match, so nothing is rendered and nothing has to be range-checked.
        // Walking the rubric rather than the model's array also fixes the order and collapses
        // a number the model happened to name twice.
        covered = concept.rubric.filter { claimed.contains($0.number) }
        missing = concept.rubric.filter { claimed.contains($0.number) == false }

        let detected = Set(feedback.misconceptions.map(\.rawValue))
        misconceptions = concept.misconceptions.filter { detected.contains($0.id) }
    }

    /// Whether a misconception was detected. The panel's one conditional section hangs off
    /// this, so "no misconception" is an absent section rather than an empty one telling the
    /// learner about a problem they do not have.
    var hasMisconception: Bool { misconceptions.isEmpty == false }
}
