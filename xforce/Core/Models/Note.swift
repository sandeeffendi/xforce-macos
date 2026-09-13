//
//  Note.swift
//  xforce
//

import Foundation
import SwiftData

/// One completed pass through the explanation loop, written once and never edited.
///
/// The immutability is the point: a note records what the learner thought at that moment, not
/// a tidied version written once they knew the answer. Every stored property is `private(set)`
/// and the type exposes no method that changes one, so editing a note is not something the
/// rest of the app can do by accident.
///
/// A note is written at commit and only at commit. An abandoned session leaves nothing behind,
/// which is what keeps "not answered yet" and "deliberately skipped" out of the stored record.
///
/// Deliberately absent: the concepts this one connects to, which are derivable from the
/// ontology's own edges rather than worth a second copy that can fall out of step with them,
/// and the missing rubric points, which are the complement of the covered ones over a rubric
/// that also ships as data. Only what the model actually judged is stored.
@Model
final class Note {

    /// The concept the snippet belongs to, referencing the read-only ontology by id.
    private(set) var conceptID: String

    /// The snippet the learner predicted the output of.
    private(set) var snippetID: String

    /// What the learner said the snippet would print, kept exactly as they typed it.
    private(set) var prediction: String

    /// Why they thought so, in their own words.
    private(set) var explanation: String

    /// The question the model asked about that reasoning, or `nil` when it was never asked
    /// because no model could be reached.
    private(set) var socraticQuestion: String?

    /// What the learner wrote back, or `nil` when they skipped the question or were never
    /// asked one. An answered question with an empty field is stored as an empty string, so
    /// "wrote nothing" and "declined to write" stay different things in the record.
    ///
    /// Evidence, never an input: nothing reads it back into the loop, which is what keeps the
    /// stored record uncontaminated by a feedback loop.
    private(set) var socraticAnswer: String?

    /// The numbers of the rubric points the model judged this explanation to have covered.
    ///
    /// Empty when there was no model to ask, which is the same thing it records when the model
    /// judged nothing covered — and the two are told apart by ``socraticQuestion`` being `nil`,
    /// exactly as a skipped and an unasked question already are.
    ///
    /// The missing points are not stored: they are the complement over the concept's authored
    /// rubric, and storing a second list is what would let the two contradict each other.
    private(set) var coveredRubricPoints: [Int]

    /// The misconceptions detected in this explanation, as authored ontology ids.
    ///
    /// Already filtered to the ones the concept owns, because this is the same set the session
    /// outcome was derived from. Stored as ids rather than as the generated enum so the record
    /// survives the enum gaining or losing a case.
    private(set) var detectedMisconceptionIDs: [String]

    /// What the session did to the concept's standing.
    private(set) var outcome: SessionOutcome

    /// When the session was committed. Doubles as the note's place in the concept's history
    /// and as the record of when the learner last saw this snippet.
    private(set) var createdAt: Date

    init(
        conceptID: String,
        snippetID: String,
        prediction: String,
        explanation: String,
        socraticQuestion: String? = nil,
        socraticAnswer: String? = nil,
        coveredRubricPoints: [Int] = [],
        detectedMisconceptionIDs: [String] = [],
        outcome: SessionOutcome,
        createdAt: Date = .now
    ) {
        self.conceptID = conceptID
        self.snippetID = snippetID
        self.prediction = prediction
        self.explanation = explanation
        self.socraticQuestion = socraticQuestion
        self.socraticAnswer = socraticAnswer
        self.coveredRubricPoints = coveredRubricPoints
        self.detectedMisconceptionIDs = detectedMisconceptionIDs
        self.outcome = outcome
        self.createdAt = createdAt
    }
}
