//
//  SchedulingService.swift
//  xforce
//

import Foundation
import Observation
import SwiftData

/// The learner's own work: the notes they have written and where each concept stands in the
/// five-box schedule.
///
/// Created once in `XforceApp` over the app's `ModelContainer` and read through `@Environment`,
/// the way `ContentService` and `Router` already are. It is the only type that touches the
/// store, so no view model holds a fetch descriptor and no view model can write half a session.
///
/// Writing the note and moving the box are one operation rather than two. A note without its
/// schedule update, or a schedule update without its note, would be a record of a session that
/// did not happen the way the store says it did.
@MainActor
@Observable
final class SchedulingService {

    /// Held, not just borrowed. A `ModelContext` does not keep its container alive, so a
    /// service that kept only `container.mainContext` would be fetching through a context
    /// whose store had already gone.
    private let container: ModelContainer
    private let modelContext: ModelContext

    init(container: ModelContainer) {
        self.container = container
        modelContext = container.mainContext

        // Every write goes through `record(_:)`, which saves explicitly. Autosaving on top of
        // that would let a half-made session reach the store on its own schedule, which is
        // exactly what the commit is supposed to be the only way in.
        modelContext.autosaveEnabled = false
    }

    /// A store held entirely in memory. The screen previews use it so that rendering a preview
    /// never writes to the learner's real store.
    static func inMemory() -> SchedulingService {
        do {
            let container = try ModelContainer(
                for: Note.self, ConceptProgress.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            return SchedulingService(container: container)
        } catch {
            fatalError("An in-memory store could not be built: \(error)")
        }
    }

    /// Records one committed session: writes the note and moves the concept through the
    /// schedule, saving both together.
    ///
    /// The note arrives already made, because it is the caller's record of what the learner
    /// did — this is where it stops being a value and becomes stored. The progress record is
    /// opened on the concept's first committed session and updated on every one after it, so
    /// a concept has exactly one however many notes it accumulates.
    ///
    /// A failed save takes both back out. Leaving the inserted note behind would let the next
    /// save write it alongside the retry's note, and one commit has to mean one note.
    ///
    /// - Returns: the concept's progress record as it now stands.
    @discardableResult
    func record(_ note: Note) throws -> ConceptProgress {
        modelContext.insert(note)

        let progress: ConceptProgress
        if let existing = try self.progress(forConceptID: note.conceptID) {
            progress = existing
        } else {
            progress = ConceptProgress(conceptID: note.conceptID, at: note.createdAt)
            modelContext.insert(progress)
        }
        progress.record(note.outcome, at: note.createdAt)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        return progress
    }

    /// Where one concept stands, or `nil` when the learner has never committed a session on it.
    func progress(forConceptID id: String) throws -> ConceptProgress? {
        var descriptor = FetchDescriptor<ConceptProgress>(
            predicate: #Predicate<ConceptProgress> { $0.conceptID == id }
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    /// Which box every concept the learner has committed a session on currently sits in,
    /// keyed by concept id.
    ///
    /// A concept absent from the result has never been attempted — a different thing from one
    /// sitting in the first box, and the distinction the graph's colouring rests on. Returned
    /// as plain values rather than as records so that the graph reads what it needs in one
    /// fetch and holds nothing from the store.
    func boxesByConceptID() throws -> [String: Int] {
        try modelContext
            .fetch(FetchDescriptor<ConceptProgress>())
            .reduce(into: [:]) { boxes, progress in
                boxes[progress.conceptID] = progress.box
            }
    }

    /// Every snippet the learner has worked through, against the last time they saw it.
    ///
    /// This is what keeps snippet selection deterministic without the selection rule knowing
    /// anything about the store: the rule is handed what has been seen and answers from the
    /// read-only content.
    func seenSnippets() throws -> [String: Date] {
        try modelContext
            .fetch(FetchDescriptor<Note>())
            .reduce(into: [:]) { seen, note in
                seen[note.snippetID] = max(seen[note.snippetID] ?? .distantPast, note.createdAt)
            }
    }
}
