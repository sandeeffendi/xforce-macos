//
//  NoteEntry.swift
//  xforce
//

import Foundation

/// One note as the inspector shows it: a whole session, read back.
///
/// A value rather than the stored record, for two reasons. The note keeps references — a
/// snippet id, rubric numbers, misconception ids — that mean nothing without the authored
/// content they point at, and resolving them is not something a view should be doing. And a
/// note is immutable, so an entry built from one can be handed around freely: it is a
/// photograph of a session, not a window onto a record that might change underneath it.
///
/// Ordering is carried rather than left to the array, because the sequence is the thing the
/// history exists to show. A concept is a long-lived entity with many notes over time, and
/// watching what the learner used to think turn into what they think now is only possible if
/// the order is explicit.
nonisolated struct NoteEntry: Identifiable, Hashable, Sendable {

    /// Where this session sits in the concept's history, counting from one at the oldest.
    let order: Int

    /// When the session was committed.
    let writtenAt: Date

    /// What it did to the concept's standing.
    let outcome: SessionOutcome

    /// The snippet's source, or `nil` when the content no longer ships that snippet. The note
    /// outlives any one version of the authored content, and is still the learner's record.
    let code: String?

    /// What the snippet really printed, or `nil` for the same reason ``code`` can be.
    let expectedOutput: String?

    /// What the learner predicted, kept exactly as they typed it.
    let prediction: String

    /// Why they thought so, in their own words.
    let explanation: String

    /// The question the model asked, or `nil` when there was no model to ask it.
    let socraticQuestion: String?

    /// What they wrote back, or `nil` when they skipped the question or were never asked one.
    /// The two are told apart by ``socraticQuestion``, exactly as they are in the record.
    let socraticAnswer: String?

    /// The model's reading of the explanation, rebuilt against the concept's authored rubric,
    /// or `nil` when no model read this session.
    ///
    /// Optional rather than empty on purpose. A session committed on a Mac with no Apple
    /// Intelligence judged nothing, and rendering that as a rubric with every point missing
    /// would tell the learner they failed at something nobody ever read.
    let reading: StructuredFeedback?

    var id: Int { order }
}
