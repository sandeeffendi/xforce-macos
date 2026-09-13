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
///
/// The map is also a way in. Selecting a concept opens its whole history — every note the
/// learner has written about it, oldest first — and offers a session on it there and then.
/// That control is the deliberate revisit path, and it stands in for the scheduled review mode
/// this milestone leaves out.
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

    /// The concept whose history the inspector is showing, or `nil` when nothing is selected.
    private(set) var selectedConceptID: String?

    /// Every note the learner has written about the selected concept, oldest first.
    private(set) var history: [NoteEntry] = []

    init(content: ContentService, scheduling: SchedulingService) {
        self.content = content
        self.scheduling = scheduling
    }

    /// The selected concept itself, resolved from the ontology rather than held, so the
    /// selection stays a value the graph can be rebuilt around.
    var selectedConcept: Concept? {
        selectedConceptID.flatMap(content.concept(withID:))
    }

    /// Whether the inspector is on screen. It appears on selection and leaves with it: there
    /// is nothing for it to say about a graph nobody has clicked into.
    var isInspectorPresented: Bool { selectedConcept != nil }

    /// Where the inspector's practise control sends the learner, or `nil` when nothing is
    /// selected.
    ///
    /// A route rather than a call into the router, so the graph's half of the navigation is a
    /// value that can be asserted on directly. Resolving it into a screen stays the one job of
    /// `RouteBuilder`, and pushing it stays the view's.
    var sessionRoute: AppRoute? {
        selectedConcept.map { .session(conceptID: $0.id) }
    }

    /// Opens one concept's history.
    ///
    /// An id the ontology does not know is not a selection at all: there would be no concept
    /// to show a history for and nothing to practise.
    func select(_ conceptID: String) {
        guard content.concept(withID: conceptID) != nil else { return }

        selectedConceptID = conceptID
        refreshHistory()
    }

    func clearSelection() {
        selectedConceptID = nil
        history = []
    }

    /// The learner asking for a session on the selected concept.
    ///
    /// The selection is let go as the route is handed back, so the map's inspector is never
    /// presented at the same time as the practice screen's. That matters more than it sounds:
    /// the practice screen's inspector *is* the gate, and the lock has to be seen for the
    /// constraint to read as intentional rather than as a broken app.
    ///
    /// - Returns: where to go, or `nil` when nothing is selected.
    func startSession() -> AppRoute? {
        guard let route = sessionRoute else { return nil }

        clearSelection()
        return route
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

        // Whenever the map is rebuilt, what the inspector is showing is rebuilt with it. A
        // history left over from the previous build would be the one part of the screen not
        // saying what the store currently holds.
        refreshHistory()
    }

    /// Reads the selected concept's notes back and turns each into a whole session again.
    private func refreshHistory() {
        guard let concept = selectedConcept else {
            history = []
            return
        }

        let notes: [Note]
        do {
            notes = try scheduling.notes(forConceptID: concept.id)
        } catch {
            return fail("Your notes could not be read: \(error.localizedDescription)")
        }

        history = notes.enumerated().map { order, note in
            entry(order: order + 1, note: note, concept: concept)
        }
    }

    /// Resolves one stored note against the authored content it refers to.
    ///
    /// The reading is rebuilt through the same type the live panel uses, from the numbers and
    /// ids the note stored, so the history and the practice screen cannot come to different
    /// conclusions about the same session. A note that was never read by a model carries no
    /// reading at all rather than an empty one.
    ///
    /// Whether a model read the session is read off the stored question rather than off a flag
    /// of its own, because that is the rule ``Note`` states: an empty list of covered points
    /// "is the same thing it records when the model judged nothing covered — and the two are
    /// told apart by `socraticQuestion` being `nil`". The loop writes both in one place at one
    /// moment, so they cannot come apart; a change that ever asked the model for a judgement
    /// without a question would have to give the record a fact of its own instead.
    private func entry(order: Int, note: Note, concept: Concept) -> NoteEntry {
        let snippet = content.snippet(withID: note.snippetID)

        return NoteEntry(
            order: order,
            writtenAt: note.createdAt,
            outcome: note.outcome,
            code: snippet?.code,
            expectedOutput: snippet?.expectedOutput,
            prediction: note.prediction,
            explanation: note.explanation,
            socraticQuestion: note.socraticQuestion,
            socraticAnswer: note.socraticAnswer,
            reading: note.socraticQuestion == nil
                ? nil
                : StructuredFeedback(
                    concept: concept,
                    coveredRubricPoints: note.coveredRubricPoints,
                    detectedMisconceptionIDs: note.detectedMisconceptionIDs
                )
        )
    }

    /// A failed graph shows the reason and nothing else. Leaving a half-built map on screen
    /// beside an error would be a map the learner could not trust — and a half-built history
    /// beside it would be worse, because it is the learner's own record.
    private func fail(_ message: String) {
        nodes = []
        edges = []
        selectedConceptID = nil
        history = []
        state = .failed(message)
    }
}
