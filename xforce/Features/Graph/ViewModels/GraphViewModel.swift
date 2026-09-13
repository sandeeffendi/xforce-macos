//
//  GraphViewModel.swift
//  xforce
//

import Foundation
import Observation

/// Builds the map of the learner's own understanding: every concept in the ontology, where it
/// was authored to sit, coloured by how well it is understood.
///
/// Two things about this screen are deliberate. It draws every concept from the first launch,
/// including ones never attempted, so there is no cold start to live through. And it depends
/// on the content and the store alone — no feedback service reaches it, so reviewing progress
/// is never gated on whether a model is available.
@MainActor
@Observable
final class GraphViewModel {

    private let content: ContentService
    private let scheduling: SchedulingService

    private(set) var state: ViewState = .idle

    /// Every concept, in authored order. Positions come from the content, so they are the same
    /// on every open.
    private(set) var nodes: [ConceptNode] = []

    /// The ontology's own prerequisite and related edges, between the nodes above.
    private(set) var edges: [ConceptEdge] = []

    init(content: ContentService, scheduling: SchedulingService) {
        self.content = content
        self.scheduling = scheduling
    }

    /// Reads the ontology and the learner's progress and rebuilds the map.
    ///
    /// Safe to run again: the same content and the same store produce the same nodes in the
    /// same places, which is what the screen's every appearance relies on.
    func load() {
        if let failure = content.failure {
            return fail(failure.message)
        }

        let boxes: [String: Int]
        do {
            boxes = try scheduling.boxesByConceptID()
        } catch {
            return fail("Your progress could not be read: \(error.localizedDescription)")
        }

        nodes = content.concepts.map { concept in
            ConceptNode(
                id: concept.id,
                name: concept.name,
                position: concept.position,
                mastery: MasteryLevel(box: boxes[concept.id])
            )
        }
        edges = ConceptEdge.edges(in: content.concepts)
        state = .loaded
    }

    /// A failed graph shows the reason and nothing else. Leaving a half-built map on screen
    /// beside an error would be a map the learner could not trust.
    private func fail(_ message: String) {
        nodes = []
        edges = []
        state = .failed(message)
    }
}
