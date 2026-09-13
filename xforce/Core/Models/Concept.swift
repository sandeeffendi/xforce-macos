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

    /// Where this concept is drawn on the graph. Authored, not computed.
    let position: ConceptPosition

    /// The concepts that have to be understood before this one, by id.
    ///
    /// Also the ontology's authoring order: a concept is authored after everything it names
    /// here, which is the same order snippet selection walks.
    let prerequisites: [String]

    /// The concepts that illuminate this one without being required first, by id.
    ///
    /// Authored rather than inferred. The graph draws its edges from these two fields and
    /// nothing else — no embeddings, no similarity, no model.
    let related: [String]

    /// The points a complete explanation of this concept would cover, numbered from one.
    ///
    /// The numbering is what later lets covered points be reported as integers and the
    /// missing ones computed as the complement.
    let rubric: [RubricPoint]

    /// The curated wrong beliefs a learner may hold about this concept.
    let misconceptions: [Misconception]

    /// The concepts this one builds on, by id.
    let prerequisites: [String]

    /// The concepts this one sits beside, by id.
    ///
    /// These edges and ``prerequisites`` are authored, and they are the *only* source of the
    /// feedback panel's "connect this" section: the model is never asked which concepts relate
    /// to which. A small on-device model choosing among a handful of concepts adds noise rather
    /// than signal, and driving the section from data removes a generated field along with a
    /// whole class of label drift. The content integrity suite asserts that every id here
    /// resolves and that no concept names itself.
    let related: [String]
}

/// Where a concept sits on the graph, in unit coordinates.
///
/// Both axes run `0...1` across whatever space the graph is given, with `y` increasing
/// downward the way screen coordinates do. Unit coordinates rather than points because an
/// authored layout should not have to know how large the window is.
///
/// The layout is authored rather than produced by a force-directed simulation. The ontology
/// is fixed and small, so a simulation would need a stepping loop, stable seeding and overlap
/// handling for no gain — and positions that never move are what let the graph become a map
/// the learner can hold in their head.
nonisolated struct ConceptPosition: Hashable, Codable, Sendable {
    let x: Double
    let y: Double

    /// The coordinate space both axes live in. The content integrity suite holds every
    /// authored position to it, because a coordinate outside this range is a node drawn off
    /// the edge of the graph.
    static let unitRange: ClosedRange<Double> = 0...1
}

/// One numbered point of a concept's rubric.
nonisolated struct RubricPoint: Identifiable, Hashable, Codable, Sendable {
    let number: Int
    let text: String

    var id: Int { number }
}

/// A wrong belief a learner may hold about a concept, paired with what replaces it.
///
/// Authored data. What a model may report about it is constrained separately, by
/// ``MisconceptionID`` — a closed generated type whose raw values are these ``id``s.
nonisolated struct Misconception: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let correction: String
}
