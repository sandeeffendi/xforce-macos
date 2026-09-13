//
//  ConceptNode.swift
//  xforce
//

import Foundation

/// One concept as the graph draws it: where it sits, what it is called, and how well the
/// learner understands it.
///
/// A node exists for every concept in the ontology from the first launch, including concepts
/// never attempted, so the graph is a map rather than an empty page waiting to be filled.
nonisolated struct ConceptNode: Identifiable, Hashable, Sendable {

    /// The concept's id, which is also the node's identity and what edges refer to.
    let id: String

    /// The concept's display name, drawn beside the node.
    let name: String

    /// The authored position, in unit coordinates. Identical on every open.
    let position: ConceptPosition

    /// How well the concept is understood, derived from its Leitner box every time the graph
    /// is built rather than stored anywhere.
    let mastery: MasteryLevel
}
