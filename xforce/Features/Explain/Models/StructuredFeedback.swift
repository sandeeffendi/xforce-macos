//
//  StructuredFeedback.swift
//  xforce
//

import Foundation

/// The feedback panel's content: everything the learner is shown once the gate opens.
///
/// Built once, from one inference plus the ontology, and then only rendered. That is what lets
/// the panel have the same sections in the same order every time — the sections are fields on
/// a value, not decisions taken while drawing.
///
/// Only two of these fields owe anything to the model, and even those are constrained:
///
/// - ``covered`` is the model's numbers **intersected with** the concept's own rubric, so a
///   number the rubric does not have simply has nothing to match and disappears.
/// - ``missing`` is the complement of ``covered`` over that same rubric, computed here. The
///   two lists therefore partition the rubric exactly once and cannot contradict each other:
///   asking the model for both is what would have made that possible.
/// - ``misconceptions`` is the model's closed-set answer filtered down to the ones this
///   concept actually owns.
/// - ``connections`` never involves the model at all. It resolves the concept's own authored
///   edges against the ontology.
nonisolated struct StructuredFeedback: Hashable, Sendable {

    /// The rubric points the explanation covered, in authored order.
    let covered: [RubricPoint]

    /// The rest of the rubric — computed, never generated.
    let missing: [RubricPoint]

    /// The detected misconceptions that belong to this concept, each carrying its correction.
    /// Empty when none was detected, which is what hides the section.
    let misconceptions: [Misconception]

    /// The concepts this one connects to, resolved from the ontology's authored edges.
    let connections: [Concept]

    /// Turns one inference into the panel.
    ///
    /// - Parameters:
    ///   - concept: the concept being practised; its rubric and misconception list are the
    ///     only things the model's answer is allowed to select from.
    ///   - feedback: what the model said, unfiltered.
    ///   - ontology: every concept, so the authored edges can be resolved to real concepts.
    init(concept: Concept, feedback: ExplanationFeedback, ontology: [Concept]) {
        let claimed = Set(feedback.coveredRubricPoints)

        // Intersecting with the authored rubric is what discards an out-of-range number: there
        // is no point to match, so nothing is rendered and nothing has to be range-checked.
        // Walking the rubric rather than the model's array also fixes the order and collapses
        // a number the model happened to name twice.
        covered = concept.rubric.filter { claimed.contains($0.number) }
        missing = concept.rubric.filter { claimed.contains($0.number) == false }

        let detected = Set(feedback.misconceptions.map(\.rawValue))
        misconceptions = concept.misconceptions.filter { detected.contains($0.id) }

        connections = Self.resolve(
            ids: concept.prerequisites + concept.related,
            excluding: concept.id,
            in: ontology
        )
    }

    /// Whether a misconception was detected. The panel's one conditional section hangs off
    /// this, so "no misconception" is an absent section rather than an empty one telling the
    /// learner about a problem they do not have.
    var hasMisconception: Bool { misconceptions.isEmpty == false }

    /// Authored order, each concept once, and only concepts that exist.
    ///
    /// An id that resolves to nothing is dropped rather than rendered: the content integrity
    /// suite already fails the build on one, so anything reaching here is not worth showing a
    /// learner a blank row over.
    private static func resolve(
        ids: [String],
        excluding selfID: String,
        in ontology: [Concept]
    ) -> [Concept] {
        var seen: Set<String> = [selfID]

        return ids.compactMap { id in
            guard seen.contains(id) == false else { return nil }
            seen.insert(id)
            return ontology.first { $0.id == id }
        }
    }
}
