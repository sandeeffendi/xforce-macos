//
//  ConceptHistoryTests.swift
//  xforceTests
//

import Foundation
import Testing
@testable import xforce

/// Seam four again, from the other side: the graph as a way in rather than as a picture.
///
/// Selecting a concept has to produce the learner's own record of it — every note they have
/// written about it, oldest first, because the sequence is the evidence of understanding
/// changing and that is the whole reason notes are immutable.
///
/// Everything here is driven from fixtures rather than from the shipped ontology. The content
/// is authored in a lane of its own, so a suite that leaned on how many concepts ship, or on
/// a concept having neighbours, would fail for a reason that has nothing to do with the graph.
@MainActor
struct ConceptNoteHistoryTests {

    @Test func selectingAConceptOpensTheInspectorOnItsNotes() throws {
        let viewModel = try graphViewModel(notes: [
            historyNote(conceptID: "optionals", snippetID: "optionals-1", at: .fixture(day: 1))
        ])

        viewModel.select("optionals")

        #expect(viewModel.isInspectorPresented)
        #expect(viewModel.selectedConcept?.id == "optionals")
        #expect(viewModel.history.count == 1)
    }

    /// The order is the point. A learner reads their own history forwards, watching what they
    /// used to think turn into what they think now.
    @Test func theNotesAreShownOldestFirstHoweverTheStoreHeldThem() throws {
        let viewModel = try graphViewModel(notes: [
            historyNote(conceptID: "optionals", snippetID: "optionals-2", explanation: "Second", at: .fixture(day: 2)),
            historyNote(conceptID: "optionals", snippetID: "optionals-3", explanation: "Third", at: .fixture(day: 3)),
            historyNote(conceptID: "optionals", snippetID: "optionals-1", explanation: "First", at: .fixture(day: 1)),
        ])

        viewModel.select("optionals")

        #expect(viewModel.history.map(\.explanation) == ["First", "Second", "Third"])
        #expect(viewModel.history.map(\.order) == [1, 2, 3])
    }

    @Test func onlyTheSelectedConceptsNotesAreShown() throws {
        let viewModel = try graphViewModel(notes: [
            historyNote(conceptID: "variables", snippetID: "variables-1", at: .fixture(day: 1)),
            historyNote(conceptID: "optionals", snippetID: "optionals-1", at: .fixture(day: 2)),
        ])

        viewModel.select("optionals")

        #expect(viewModel.history.map(\.code) == ["print(optionals-1)"])
    }

    /// Every part of the session the learner committed has to come back, or the record is a
    /// summary of their thinking rather than the thing itself.
    @Test func anEntryCarriesTheWholeSession() throws {
        let viewModel = try graphViewModel(notes: [
            historyNote(
                conceptID: "optionals",
                snippetID: "optionals-1",
                prediction: "5",
                explanation: "I thought the wrapper would be gone.",
                socraticQuestion: "What told you the wrapper would be gone?",
                socraticAnswer: "Nothing, I assumed it.",
                coveredRubricPoints: [1],
                detectedMisconceptionIDs: ["optionals-printing"],
                outcome: .failed,
                at: .fixture(day: 1)
            )
        ])

        viewModel.select("optionals")
        let entry = try #require(viewModel.history.first)

        #expect(entry.code == "print(optionals-1)")
        #expect(entry.expectedOutput == "Optional(5)")
        #expect(entry.prediction == "5")
        #expect(entry.explanation == "I thought the wrapper would be gone.")
        #expect(entry.socraticQuestion == "What told you the wrapper would be gone?")
        #expect(entry.socraticAnswer == "Nothing, I assumed it.")
        #expect(entry.outcome == .failed)
        #expect(entry.writtenAt == .fixture(day: 1))
    }

    /// The same filtering the live panel does, from the same type, so the two surfaces cannot
    /// come to different conclusions about what the model said.
    @Test func theModelsReadingIsRebuiltAgainstTheConceptsOwnRubric() throws {
        let viewModel = try graphViewModel(notes: [
            historyNote(
                conceptID: "optionals",
                snippetID: "optionals-1",
                coveredRubricPoints: [2, 99],
                detectedMisconceptionIDs: ["optionals-printing", "variables-shadowing"],
                at: .fixture(day: 1)
            )
        ])

        viewModel.select("optionals")
        let reading = try #require(viewModel.history.first?.reading)

        #expect(reading.covered.map(\.number) == [2])
        #expect(reading.missing.map(\.number) == [1, 3])
        #expect(reading.misconceptions.map(\.id) == ["optionals-printing"])
    }

    /// A skipped question and an answered one are different things to know about someone's
    /// thinking, and the record keeps them apart.
    @Test func aSkippedQuestionIsToldApartFromAnAnsweredOne() throws {
        let viewModel = try graphViewModel(notes: [
            historyNote(
                conceptID: "optionals",
                snippetID: "optionals-1",
                socraticQuestion: "Why?",
                socraticAnswer: nil,
                at: .fixture(day: 1)
            ),
            historyNote(
                conceptID: "optionals",
                snippetID: "optionals-2",
                socraticQuestion: "Why?",
                socraticAnswer: "",
                at: .fixture(day: 2)
            ),
        ])

        viewModel.select("optionals")

        // Both were asked. The first declined to answer and stored nothing; the second
        // answered with an empty field, which is still an answer.
        #expect(viewModel.history.map(\.socraticQuestion) == ["Why?", "Why?"])
        #expect(viewModel.history.map(\.socraticAnswer) == [nil, ""])
    }

    /// A session committed on a Mac with no model judged nothing. Rendering that as a rubric
    /// with every point missing would tell the learner they failed at something nobody read.
    @Test func aSessionNoModelReadCarriesNoReadingRatherThanAnEmptyOne() throws {
        let viewModel = try graphViewModel(notes: [
            historyNote(
                conceptID: "optionals",
                snippetID: "optionals-1",
                socraticQuestion: nil,
                socraticAnswer: nil,
                at: .fixture(day: 1)
            )
        ])

        viewModel.select("optionals")
        let entry = try #require(viewModel.history.first)

        #expect(entry.socraticQuestion == nil)
        #expect(entry.reading == nil)
    }

    /// Notes are immutable and the content is authored in a lane of its own, so a note can
    /// outlive the snippet it names. The note is still the learner's record and is still shown.
    @Test func aNoteWhoseSnippetHasLeftTheContentIsStillShown() throws {
        let viewModel = try graphViewModel(notes: [
            historyNote(conceptID: "optionals", snippetID: "retired-snippet", at: .fixture(day: 1))
        ])

        viewModel.select("optionals")
        let entry = try #require(viewModel.history.first)

        #expect(entry.code == nil)
        #expect(entry.expectedOutput == nil)
        #expect(entry.prediction.isEmpty == false)
    }

    @Test func selectingAnotherConceptReplacesTheHistory() throws {
        let viewModel = try graphViewModel(notes: [
            historyNote(conceptID: "variables", snippetID: "variables-1", explanation: "Variables", at: .fixture(day: 1)),
            historyNote(conceptID: "optionals", snippetID: "optionals-1", explanation: "Optionals", at: .fixture(day: 2)),
        ])

        viewModel.select("optionals")
        viewModel.select("variables")

        #expect(viewModel.selectedConcept?.id == "variables")
        #expect(viewModel.history.map(\.explanation) == ["Variables"])
    }

    @Test func clearingTheSelectionClosesTheInspector() throws {
        let viewModel = try graphViewModel(notes: [
            historyNote(conceptID: "optionals", snippetID: "optionals-1", at: .fixture(day: 1))
        ])
        viewModel.select("optionals")

        viewModel.clearSelection()

        #expect(viewModel.isInspectorPresented == false)
        #expect(viewModel.selectedConcept == nil)
        #expect(viewModel.history.isEmpty)
    }

    /// Selecting a concept that is not in the ontology is not a selection at all — there is
    /// nothing to show and nothing to practise.
    @Test func selectingAConceptThatDoesNotShipSelectsNothing() throws {
        let viewModel = try graphViewModel()

        viewModel.select("vanished-concept")

        #expect(viewModel.isInspectorPresented == false)
        #expect(viewModel.history.isEmpty)
    }

    /// The screen reloads whenever it comes back on, which is exactly what happens when the
    /// learner returns from the session the inspector started.
    @Test func reloadingPicksUpANoteWrittenSinceTheConceptWasSelected() throws {
        let scheduling = SchedulingService.inMemory()
        let viewModel = GraphViewModel(
            content: ContentService(library: .historyFixture()),
            scheduling: scheduling
        )
        viewModel.load()
        viewModel.select("optionals")
        #expect(viewModel.history.isEmpty)

        try scheduling.record(historyNote(conceptID: "optionals", snippetID: "optionals-1", at: .fixture(day: 1)))
        viewModel.load()

        #expect(viewModel.history.count == 1)
    }
}

/// A concept nobody has written about yet is an invitation, not a failure.
@MainActor
struct ConceptEmptyHistoryTests {

    @Test func aConceptWithNoNotesStillOpensTheInspector() throws {
        let viewModel = try graphViewModel()

        viewModel.select("optionals")

        #expect(viewModel.isInspectorPresented)
        #expect(viewModel.selectedConcept?.name == "Optionals")
        #expect(viewModel.history.isEmpty)
    }

    /// The empty state's whole job is to offer the first session, so the control that starts
    /// one has to be there before there is any history at all.
    @Test func anEmptyHistoryStillOffersTheFirstSession() throws {
        let viewModel = try graphViewModel()

        viewModel.select("optionals")

        #expect(viewModel.sessionRoute == .session(conceptID: "optionals"))
    }
}

/// The deliberate revisit path: what the inspector's control does, and what the loop it starts
/// puts in front of the learner.
@MainActor
struct ConceptRevisitTests {

    @Test func theInspectorOffersASessionOnTheSelectedConcept() throws {
        let viewModel = try graphViewModel()

        viewModel.select("variables")

        #expect(viewModel.sessionRoute == .session(conceptID: "variables"))
    }

    @Test func nothingSelectedOffersNoSession() throws {
        let viewModel = try graphViewModel()

        #expect(viewModel.sessionRoute == nil)
        #expect(viewModel.startSession() == nil)
    }

    /// The practice screen's own inspector is the gate, and the lock has to be seen. Letting
    /// the map's inspector go as the session starts is what keeps the two from being presented
    /// over each other.
    @Test func startingASessionLetsTheMapsInspectorGo() throws {
        let viewModel = try graphViewModel(notes: [
            historyNote(conceptID: "optionals", snippetID: "optionals-1", at: .fixture(day: 1))
        ])
        viewModel.select("optionals")

        let route = viewModel.startSession()

        #expect(route == .session(conceptID: "optionals"))
        #expect(viewModel.isInspectorPresented == false)
        #expect(viewModel.history.isEmpty)
    }

    /// Recalling rather than remembering a specific answer: a revisit goes to a snippet the
    /// learner has not met, even though the loop's own rule would have sent them elsewhere.
    @Test func aRevisitStartsOnASnippetTheLearnerHasNotSeen() throws {
        let scheduling = SchedulingService.inMemory()
        try scheduling.record(
            practiceNote(conceptID: "optionals", snippetID: "optionals-1", at: .fixture(day: 1))
        )

        let viewModel = revisitViewModel(conceptID: "optionals", scheduling: scheduling)
        viewModel.load()

        #expect(viewModel.concept?.id == "optionals")
        #expect(viewModel.snippet?.id == "optionals-2")
    }

    /// Once every snippet has been met there is nothing unseen left to rank, so the one seen
    /// longest ago comes back round — the same fallback the loop's own selection uses.
    @Test func aRevisitFallsBackToTheSnippetSeenLongestAgo() throws {
        let scheduling = SchedulingService.inMemory()
        try scheduling.record(
            practiceNote(conceptID: "optionals", snippetID: "optionals-1", at: .fixture(day: 3))
        )
        try scheduling.record(
            practiceNote(conceptID: "optionals", snippetID: "optionals-2", at: .fixture(day: 1))
        )
        try scheduling.record(
            practiceNote(conceptID: "optionals", snippetID: "optionals-3", at: .fixture(day: 2))
        )

        let viewModel = revisitViewModel(conceptID: "optionals", scheduling: scheduling)
        viewModel.load()

        #expect(viewModel.snippet?.id == "optionals-2")
    }

    /// Without the concept the loop's own rule picks the earliest concept with something
    /// unseen, which is what makes the revisit a different journey rather than the same one.
    @Test func withoutAConceptTheLoopChoosesForItself() {
        let viewModel = ExplainViewModel(
            content: ContentService(library: .practiceFixture()),
            feedback: FakeFeedbackService(),
            scheduling: .inMemory()
        )

        viewModel.load()

        #expect(viewModel.concept?.id == "variables")
    }

    /// The hard gate is not bypassable through this door: a revisit is an ordinary pass
    /// through the loop, starting where every pass starts.
    @Test func aRevisitStartsAtThePromptWithTheGateIntact() {
        let viewModel = revisitViewModel(conceptID: "optionals", scheduling: .inMemory())

        viewModel.load()

        #expect(viewModel.state == .loaded)
        #expect(viewModel.phase == .prompt)
        #expect(viewModel.isFeedbackLocked)
        #expect(viewModel.expectedOutput == nil)
        #expect(viewModel.structuredFeedback == nil)
        #expect(viewModel.canCommit == false)
    }

    @Test func aConceptWithNothingAuthoredToPractiseSaysSoRatherThanShowingAnEmptyLoop() {
        let viewModel = ExplainViewModel(
            content: ContentService(library: .historyFixture()),
            feedback: FakeFeedbackService(),
            scheduling: .inMemory(),
            conceptID: "closures"
        )

        viewModel.load()

        #expect(viewModel.snippet == nil)
        if case .failed = viewModel.state {} else {
            Issue.record("A concept with no snippets must explain itself rather than load.")
        }
    }
}

// MARK: - Fixtures

@MainActor
private func graphViewModel(notes: [Note] = []) throws -> GraphViewModel {
    let scheduling = SchedulingService.inMemory()
    for note in notes {
        try scheduling.record(note)
    }

    let viewModel = GraphViewModel(
        content: ContentService(library: .historyFixture()),
        scheduling: scheduling
    )
    viewModel.load()
    return viewModel
}

@MainActor
private func revisitViewModel(conceptID: String, scheduling: SchedulingService) -> ExplainViewModel {
    ExplainViewModel(
        content: ContentService(library: .practiceFixture()),
        feedback: FakeFeedbackService(),
        scheduling: scheduling,
        conceptID: conceptID
    )
}

private func historyNote(
    conceptID: String,
    snippetID: String,
    prediction: String = "Optional(5)",
    explanation: String = "Because printing an optional shows the wrapper.",
    socraticQuestion: String? = "What told you that?",
    socraticAnswer: String? = "The wrapper is part of the type.",
    coveredRubricPoints: [Int] = [],
    detectedMisconceptionIDs: [String] = [],
    outcome: SessionOutcome = .mastered,
    at date: Date
) -> Note {
    Note(
        conceptID: conceptID,
        snippetID: snippetID,
        prediction: prediction,
        explanation: explanation,
        socraticQuestion: socraticQuestion,
        socraticAnswer: socraticAnswer,
        coveredRubricPoints: coveredRubricPoints,
        detectedMisconceptionIDs: detectedMisconceptionIDs,
        outcome: outcome,
        createdAt: date
    )
}

private func practiceNote(conceptID: String, snippetID: String, at date: Date) -> Note {
    Note(
        conceptID: conceptID,
        snippetID: snippetID,
        prediction: "1",
        explanation: "Because it prints one.",
        outcome: .mastered,
        createdAt: date
    )
}

private extension Date {

    /// A fixed calendar rather than `.now`, so the order a suite asserts is the order it
    /// authored and never the order the clock happened to tick in.
    static func fixture(day: Int) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000) + Double(day) * 86_400
    }
}

extension ContentLibrary {

    /// Two concepts with real rubrics and curated misconceptions, plus one concept with
    /// nothing authored to practise yet. Snippets are named after themselves so a test can
    /// tell which one an entry came from by reading its code.
    static func historyFixture() -> ContentLibrary {
        ContentLibrary(
            concepts: [
                Concept(
                    id: "variables",
                    name: "Variables",
                    summary: "A name bound to a value.",
                    position: ConceptPosition(x: 0.2, y: 0.5),
                    prerequisites: [],
                    related: [],
                    rubric: [RubricPoint(number: 1, text: "A let binding cannot be reassigned.")],
                    misconceptions: [
                        Misconception(
                            id: "variables-shadowing",
                            name: "An inner name replaces the outer one",
                            correction: "It shadows it for the length of the scope."
                        )
                    ]
                ),
                Concept(
                    id: "optionals",
                    name: "Optionals",
                    summary: "A value that may be absent.",
                    position: ConceptPosition(x: 0.6, y: 0.5),
                    prerequisites: ["variables"],
                    related: [],
                    rubric: [
                        RubricPoint(number: 1, text: "An optional either holds a value or holds nil."),
                        RubricPoint(number: 2, text: "Printing an optional shows the wrapper."),
                        RubricPoint(number: 3, text: "The value has to be unwrapped before use."),
                    ],
                    misconceptions: [
                        Misconception(
                            id: "optionals-printing",
                            name: "Printing an optional prints the value it holds",
                            correction: "It shows the Optional(...) wrapper."
                        )
                    ]
                ),
                Concept(
                    id: "closures",
                    name: "Closures",
                    summary: "A function that captures its surroundings.",
                    position: ConceptPosition(x: 0.9, y: 0.5),
                    prerequisites: [],
                    related: [],
                    rubric: [],
                    misconceptions: []
                ),
            ],
            snippets: [
                Snippet(id: "variables-1", conceptID: "variables", code: "print(variables-1)", expectedOutput: "1"),
                Snippet(id: "optionals-1", conceptID: "optionals", code: "print(optionals-1)", expectedOutput: "Optional(5)"),
                Snippet(id: "optionals-2", conceptID: "optionals", code: "print(optionals-2)", expectedOutput: "Optional(6)"),
                Snippet(id: "optionals-3", conceptID: "optionals", code: "print(optionals-3)", expectedOutput: "Optional(7)"),
            ]
        )
    }
}
