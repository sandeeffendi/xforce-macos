//
//  Concept.swift
//  xforce
//

import Foundation

/// A unit of the fixed Swift ontology the learner works through.
///
/// Concepts are authored, ship as read-only bundle data, and are never written at runtime.
/// They live in `Core` rather than in a feature because both the practice feature and the
/// graph feature need them, and features may not import each other.
nonisolated struct Concept: Identifiable, Hashable, Codable, Sendable {

    /// Stable authored identifier, referenced by snippets and by the graph.
    let id: String

    /// Display name shown above the snippet.
    let name: String

    /// A short frame for the learner's explanation. Deliberately not the answer.
    let summary: String

    /// The points a complete explanation of this concept would cover, numbered from one.
    ///
    /// The numbering is what later lets covered points be reported as integers and the
    /// missing ones computed as the complement.
    let rubric: [RubricPoint]

    /// The curated wrong beliefs a learner may hold about this concept.
    let misconceptions: [Misconception]
}

/// One numbered point of a concept's rubric.
nonisolated struct RubricPoint: Identifiable, Hashable, Codable, Sendable {
    let number: Int
    let text: String

    var id: Int { number }
}

/// A wrong belief a learner may hold about a concept, paired with what replaces it.
///
/// Authored data for now. The closed generated type that constrains what a model may report
/// arrives with the feedback slice, which is the first requirement that needs one.
nonisolated struct Misconception: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let correction: String
}
