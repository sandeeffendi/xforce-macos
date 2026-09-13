//
//  ConceptEdge.swift
//  xforce
//

import Foundation

/// A line between two concepts on the graph.
///
/// Edges come from the ontology's own authored `prerequisites` and `related` fields and from
/// nothing else. No embeddings and no similarity: the ontology already carries correct edges,
/// and a model choosing among a handful of concepts would add noise rather than signal.
nonisolated struct ConceptEdge: Identifiable, Hashable, Sendable {

    /// What kind of relationship the line stands for.
    enum Kind: Hashable, Sendable {

        /// `from` has to be understood before `to`. Directional.
        case prerequisite

        /// The two illuminate each other, in no particular order.
        case related
    }

    let from: String
    let to: String
    let kind: Kind

    /// One line per pair of concepts, so the pair is the identity. A pair authored as both a
    /// prerequisite and a relationship is one edge, not two.
    var id: String { "\(from)-\(to)" }
}

extension ConceptEdge {

    /// Every edge the ontology asks for, in authored order.
    ///
    /// Prerequisites are laid down first and a pair already connected is not connected twice,
    /// so a pair authored both ways round is drawn once and a pair authored as both kinds is
    /// drawn as the prerequisite — the stronger statement of the two. Edges naming a concept
    /// that does not ship, or naming their own concept, are dropped rather than drawn into
    /// nowhere.
    static func edges(in concepts: [Concept]) -> [ConceptEdge] {
        let known = Set(concepts.map(\.id))
        var connected: Set<Pair> = []
        var edges: [ConceptEdge] = []

        func connect(_ from: String, _ to: String, kind: Kind) {
            guard from != to, known.contains(from), known.contains(to) else { return }
            guard connected.insert(Pair(from, to)).inserted else { return }

            edges.append(ConceptEdge(from: from, to: to, kind: kind))
        }

        for concept in concepts {
            for prerequisite in concept.prerequisites {
                connect(prerequisite, concept.id, kind: .prerequisite)
            }
        }

        for concept in concepts {
            for neighbour in concept.related {
                connect(concept.id, neighbour, kind: .related)
            }
        }

        return edges
    }

    /// Two concept ids with the order thrown away, so "a related to b" and "b related to a"
    /// are recognised as the same line.
    private struct Pair: Hashable {
        let lower: String
        let upper: String

        init(_ one: String, _ other: String) {
            lower = min(one, other)
            upper = max(one, other)
        }
    }
}
