//
//  CommitTests.swift
//  xforceTests
//

import Foundation
import SwiftData
import Testing
@testable import xforce

/// Seam three: what a committed session leaves behind.
///
/// Every suite here runs against an in-memory store, so a test run leaves nothing on disk.
@MainActor
struct LeitnerScheduleTests {

    @Test func aNewConceptOpensInTheFirstBox() {
        let progress = ConceptProgress(conceptID: "optionals", at: .distantPast)

        #expect(progress.box == 1)
    }

    @Test func masteredMovesTheConceptUpOneBox() {
        let progress = ConceptProgress(conceptID: "optionals", at: .distantPast)

        progress.record(.mastered, at: .now)

        #expect(progress.box == 2)
    }

    @Test func masteredStopsAtTheLastBox() {
        let progress = ConceptProgress(conceptID: "optionals", at: .distantPast)

        for _ in 1...10 {
            progress.record(.mastered, at: .now)
        }

        #expect(progress.box == 5)
    }

    @Test func fragileLeavesTheBoxExactlyWhereItWas() {
        let progress = ConceptProgress(conceptID: "optionals", at: .distantPast)
        progress.record(.mastered, at: .now)
        progress.record(.mastered, at: .now)

        progress.record(.fragile, at: .now)

        #expect(progress.box == 3)
    }

    @Test func failedSendsTheConceptBackToTheFirstBox() {
        let progress = ConceptProgress(conceptID: "optionals", at: .distantPast)
        for _ in 1...4 {
            progress.record(.mastered, at: .now)
        }

        progress.record(.failed, at: .now)

        #expect(progress.box == 1)
    }

    @Test func failedInTheFirstBoxStaysInTheFirstBox() {
        let progress = ConceptProgress(conceptID: "optionals", at: .distantPast)

        progress.record(.failed, at: .now)

        #expect(progress.box == 1)
    }

    /// The five intervals, asserted through the record rather than by reading a table back.
    @Test(arguments: [(box: 1, days: 1), (box: 2, days: 3), (box: 3, days: 7), (box: 4, days: 16), (box: 5, days: 35)])
    func eachBoxCarriesItsOwnInterval(testCase: (box: Int, days: Int)) {
        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let progress = ConceptProgress(conceptID: "optionals", at: reviewedAt)

        // One mastered session per box above the first is what lifts the record into that box.
        for _ in 1..<testCase.box {
            progress.record(.mastered, at: reviewedAt)
        }
        if testCase.box == 1 {
            progress.record(.failed, at: reviewedAt)
        }

        #expect(progress.box == testCase.box)
        #expect(progress.lastReviewedAt == reviewedAt)
        #expect(daysBetween(progress.lastReviewedAt, progress.dueAt) == testCase.days)
    }

    @Test func masteryIsDerivedFromTheBoxAndUntouchedIsNotTheSameAsWeak() {
        #expect(MasteryLevel(box: nil) == .untouched)
        #expect(MasteryLevel(box: 1) == .weak)
        #expect(MasteryLevel(box: 2) == .developing)
        #expect(MasteryLevel(box: 3) == .developing)
        #expect(MasteryLevel(box: 4) == .strong)
        #expect(MasteryLevel(box: 5) == .strong)
    }

    @Test func aRecordReportsItsOwnMasteryLevelFromItsBox() {
        let progress = ConceptProgress(conceptID: "optionals", at: .now)

        #expect(progress.masteryLevel == .weak)

        progress.record(.mastered, at: .now)
        progress.record(.mastered, at: .now)
        progress.record(.mastered, at: .now)

        #expect(progress.box == 4)
        #expect(progress.masteryLevel == .strong)
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int? {
        Calendar.current.dateComponents([.day], from: start, to: end).day
    }
}

/// The store itself: what one commit writes, and that it is still there afterwards.
@MainActor
struct SchedulingServiceTests {

    private let container: ModelContainer
    private let scheduling: SchedulingService

    init() throws {
        container = try ModelContainer.inMemoryForTesting()
        scheduling = SchedulingService(container: container)
    }

    @Test func recordingASessionWritesExactlyOneNoteAndOneProgressRecord() throws {
        try scheduling.record(
            Note(
                conceptID: "optionals",
                snippetID: "optionals-1",
                prediction: "Optional(5)",
                explanation: "Printing an optional shows the wrapper.",
                outcome: .mastered
            )
        )

        #expect(try notes().count == 1)
        #expect(try progressRecords().count == 1)
    }

    @Test func theNoteKeepsWhatTheLearnerActuallyWrote() throws {
        try scheduling.record(
            Note(
                conceptID: "optionals",
                snippetID: "optionals-1",
                prediction: "Optional(5)",
                explanation: "Printing an optional shows the wrapper.",
                outcome: .mastered
            )
        )

        let note = try #require(try notes().first)
        #expect(note.conceptID == "optionals")
        #expect(note.snippetID == "optionals-1")
        #expect(note.prediction == "Optional(5)")
        #expect(note.explanation == "Printing an optional shows the wrapper.")
        #expect(note.outcome == .mastered)
    }

    @Test func aSecondSessionOnTheSameConceptAddsANoteButReusesTheProgressRecord() throws {
        try scheduling.record(
            Note(
                conceptID: "optionals",
                snippetID: "optionals-1",
                prediction: "Optional(5)",
                explanation: "The wrapper is printed.",
                outcome: .mastered
            )
        )
        try scheduling.record(
            Note(
                conceptID: "optionals",
                snippetID: "optionals-2",
                prediction: "Anonymous",
                explanation: "The fallback is used.",
                outcome: .mastered
            )
        )

        #expect(try notes().count == 2)
        #expect(try progressRecords().count == 1)
        #expect(try scheduling.progress(forConceptID: "optionals")?.box == 3)
    }

    @Test func eachConceptGetsItsOwnProgressRecord() throws {
        try scheduling.record(
            Note(
                conceptID: "variables",
                snippetID: "variables-1",
                prediction: "1",
                explanation: "It prints one.",
                outcome: .mastered
            )
        )
        try scheduling.record(
            Note(
                conceptID: "optionals",
                snippetID: "optionals-1",
                prediction: "wrong",
                explanation: "I guessed.",
                outcome: .failed
            )
        )

        #expect(try progressRecords().count == 2)
        #expect(try scheduling.progress(forConceptID: "variables")?.box == 2)
        #expect(try scheduling.progress(forConceptID: "optionals")?.box == 1)
    }

    @Test func aConceptNeverPractisedHasNoProgressRecordAtAll() throws {
        #expect(try scheduling.progress(forConceptID: "optionals") == nil)
    }

    /// Relaunching the app is a new context over the same store. Anything that lived only in
    /// the context the commit used would disappear at that point, so reading both records back
    /// through a fresh context is what shows they were written down rather than remembered.
    @Test func notesAndProgressOutliveTheContextThatWroteThem() throws {
        try scheduling.record(
            Note(
                conceptID: "optionals",
                snippetID: "optionals-1",
                prediction: "Optional(5)",
                explanation: "The wrapper is printed.",
                outcome: .mastered
            )
        )

        let reread = ModelContext(container)

        #expect(try reread.fetch(FetchDescriptor<Note>()).count == 1)
        #expect(try reread.fetch(FetchDescriptor<ConceptProgress>()).first?.box == 2)
    }

    @Test func everySnippetTheLearnerHasSeenIsReportedWithWhenTheyLastSawIt() throws {
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let second = first.addingTimeInterval(3600)

        try scheduling.record(
            Note(
                conceptID: "optionals",
                snippetID: "optionals-1",
                prediction: "Optional(5)",
                explanation: "The wrapper is printed.",
                outcome: .mastered,
                createdAt: first
            )
        )
        try scheduling.record(
            Note(
                conceptID: "optionals",
                snippetID: "optionals-1",
                prediction: "Optional(5)",
                explanation: "Again.",
                outcome: .mastered,
                createdAt: second
            )
        )

        let seen = try scheduling.seenSnippets()
        #expect(seen.count == 1)
        #expect(seen["optionals-1"] == second)
    }

    private func notes() throws -> [Note] {
        try container.mainContext.fetch(FetchDescriptor<Note>())
    }

    private func progressRecords() throws -> [ConceptProgress] {
        try container.mainContext.fetch(FetchDescriptor<ConceptProgress>())
    }
}

/// Which snippet the learner is put on, given what they have already worked through.
@MainActor
struct SnippetSelectionTests {

    private let content = ContentService(library: .practiceFixture())

    @Test func anUntouchedLearnerStartsOnTheFirstSnippetOfTheFirstConcept() {
        #expect(content.nextSnippet(seen: [:])?.id == "variables-1")
    }

    @Test func theNextSnippetIsOneTheLearnerHasNotSeenForThatConcept() {
        let seen = ["variables-1": Date(timeIntervalSince1970: 1_700_000_000)]

        #expect(content.nextSnippet(seen: seen)?.id == "variables-2")
    }

    @Test func theLoopMovesOnToTheNextConceptOnlyOnceTheCurrentOneIsExhausted() {
        let seen = [
            "variables-1": Date(timeIntervalSince1970: 1_700_000_000),
            "variables-3": Date(timeIntervalSince1970: 1_700_000_100),
        ]

        #expect(content.nextSnippet(seen: seen)?.id == "variables-2")

        let exhausted = seen.merging(["variables-2": Date(timeIntervalSince1970: 1_700_000_200)]) { _, new in new }

        #expect(content.nextSnippet(seen: exhausted)?.id == "optionals-1")
    }

    @Test func withEverythingSeenTheOneSeenLongestAgoComesBackRound() {
        var seen: [String: Date] = [:]
        for (index, snippet) in content.snippets.enumerated() {
            seen[snippet.id] = Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
        }
        seen["optionals-2"] = Date(timeIntervalSince1970: 1_600_000_000)

        #expect(content.nextSnippet(seen: seen)?.id == "optionals-2")
    }

    @Test func selectingIsDeterministicSoTheSameHistoryAlwaysChoosesTheSameSnippet() {
        let seen = ["variables-1": Date(timeIntervalSince1970: 1_700_000_000)]

        let chosen = (1...20).map { _ in content.nextSnippet(seen: seen)?.id }

        #expect(Set(chosen.compactMap { $0 }).count == 1)
    }
}

/// The commit as the learner drives it, through the same intent methods the screen calls.
///
/// The gate sits in front of all of this: a session cannot be written down until the learner
/// has been asked about their reasoning and has answered or skipped, so every commit here is
/// driven through the fake model conformance rather than straight off the reveal.
@MainActor
struct ExplainCommitTests {

    private let container: ModelContainer
    private let scheduling: SchedulingService
    private let content = ContentService(library: .practiceFixture())

    init() throws {
        container = try ModelContainer.inMemoryForTesting()
        scheduling = SchedulingService(container: container)
    }

    @Test func committingIsRefusedUntilTheQuestionHasBeenAnsweredOrSkipped() async throws {
        let viewModel = makeViewModel()
        viewModel.load()

        #expect(viewModel.canCommit == false)
        viewModel.commit()
        #expect(viewModel.phase == .prompt)

        submitCorrectly(viewModel)
        #expect(viewModel.canCommit == false)
        viewModel.commit()
        #expect(viewModel.phase == .reveal)

        await finishGenerating(viewModel)
        #expect(viewModel.phase == .socratic)
        #expect(viewModel.canCommit == false)
        viewModel.commit()
        #expect(viewModel.phase == .socratic)

        #expect(try notes().isEmpty)

        viewModel.answer()

        #expect(viewModel.canCommit)
    }

    @Test func committingWritesOneNoteAndOneProgressRecordAndAdvancesTheLoop() async throws {
        let viewModel = makeViewModel()
        await reachFeedback(viewModel, answering: "The wrapper would be printed instead.")

        viewModel.commit()

        #expect(viewModel.phase == .committed)

        let written = try notes()
        #expect(written.count == 1)
        #expect(written.first?.conceptID == "variables")
        #expect(written.first?.snippetID == "variables-1")
        #expect(written.first?.prediction == "1")
        #expect(written.first?.explanation == "Because that is what the snippet prints.")
        #expect(written.first?.socraticQuestion == FakeFeedbackService.defaultQuestion)
        #expect(written.first?.socraticAnswer == "The wrapper would be printed instead.")
        #expect(written.first?.outcome == .mastered)
        #expect(try progressRecords().count == 1)
        #expect(viewModel.progress?.box == 2)
    }

    /// A skip and an empty answer are different things, and the note has to keep them apart.
    @Test func aSkippedQuestionIsRecordedAsNoAnswerAtAll() async throws {
        let viewModel = makeViewModel()
        await reachFeedback(viewModel, answering: nil)

        viewModel.commit()

        let note = try #require(try notes().first)
        #expect(note.socraticQuestion == FakeFeedbackService.defaultQuestion)
        #expect(note.socraticAnswer == nil)
    }

    /// The commit needs no model at all. A Mac that cannot ask the question still records the
    /// session, and the note says plainly that no question was asked.
    @Test func aSessionIsCommittedEvenWithNoModelToAskTheQuestion() throws {
        let viewModel = makeViewModel(availability: .deviceNotEligible)
        viewModel.load()
        submitCorrectly(viewModel)

        #expect(viewModel.phase == .feedback)

        viewModel.commit()

        #expect(viewModel.phase == .committed)

        let note = try #require(try notes().first)
        #expect(note.socraticQuestion == nil)
        #expect(note.socraticAnswer == nil)
        #expect(viewModel.progress?.box == 2)
    }

    @Test func oneCommitProducesOneNoteHoweverOftenTheControlIsPressed() async throws {
        let viewModel = makeViewModel()
        await reachFeedback(viewModel)

        viewModel.commit()
        viewModel.commit()
        viewModel.commit()

        #expect(try notes().count == 1)
        #expect(try progressRecords().count == 1)
        #expect(viewModel.progress?.box == 2)
    }

    @Test func aWrongPredictionResetsTheConceptToTheFirstBox() async throws {
        try scheduling.record(
            Note(
                conceptID: "variables",
                snippetID: "variables-3",
                prediction: "3",
                explanation: "An earlier session that went well.",
                outcome: .mastered
            )
        )
        try scheduling.record(
            Note(
                conceptID: "variables",
                snippetID: "variables-2",
                prediction: "2",
                explanation: "And another.",
                outcome: .mastered
            )
        )
        #expect(try scheduling.progress(forConceptID: "variables")?.box == 3)

        let viewModel = makeViewModel()
        viewModel.load()
        viewModel.prediction = "something else entirely"
        viewModel.explanation = "I am guessing."
        viewModel.submit()
        await finishGenerating(viewModel)
        viewModel.skip()

        viewModel.commit()

        #expect(viewModel.outcome == .incorrect)
        #expect(try notes().last(where: { $0.snippetID == "variables-1" })?.outcome == .failed)
        #expect(viewModel.progress?.box == 1)
    }

    @Test func committingChoosesASnippetTheLearnerHasNotSeenForThatConcept() async throws {
        let viewModel = makeViewModel()
        viewModel.load()
        #expect(viewModel.snippet?.id == "variables-1")
        await reachFeedback(viewModel, loading: false)

        viewModel.commit()

        #expect(viewModel.nextSnippet?.id == "variables-2")

        viewModel.startNextSnippet()

        #expect(viewModel.snippet?.id == "variables-2")
        #expect(viewModel.phase == .prompt)
        #expect(viewModel.prediction.isEmpty)
        #expect(viewModel.explanation.isEmpty)
        #expect(viewModel.diff == nil)
        #expect(viewModel.outcome == nil)
        #expect(viewModel.expectedOutput == nil)
        #expect(viewModel.socraticQuestion == nil)
        #expect(viewModel.socraticResponse == nil)
        #expect(viewModel.isFeedbackLocked)
    }

    @Test func thereIsNoMovingOnBeforeTheSessionIsCommitted() async {
        let viewModel = makeViewModel()
        await reachFeedback(viewModel)

        viewModel.startNextSnippet()

        #expect(viewModel.phase == .feedback)
        #expect(viewModel.snippet?.id == "variables-1")
    }

    /// Relaunching is a fresh view model over the same store. What the learner did last time
    /// is what stops them being handed the same snippet again.
    @Test func whatWasCommittedSurvivesIntoTheNextLaunch() async throws {
        let first = makeViewModel()
        await reachFeedback(first)
        first.commit()

        let relaunched = makeViewModel()
        relaunched.load()

        #expect(relaunched.snippet?.id == "variables-2")
        #expect(try notes().count == 1)
    }

    private func makeViewModel(availability: FeedbackAvailability = .available) -> ExplainViewModel {
        ExplainViewModel(
            content: content,
            feedback: FakeFeedbackService(availability: availability),
            scheduling: scheduling
        )
    }

    /// Drives a session as far as the commit: predict correctly, be asked the question, and
    /// either answer it or skip it.
    private func reachFeedback(
        _ viewModel: ExplainViewModel,
        answering answer: String? = nil,
        loading: Bool = true
    ) async {
        if loading {
            viewModel.load()
        }
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        if let answer {
            viewModel.socraticAnswer = answer
            viewModel.answer()
        } else {
            viewModel.skip()
        }
    }

    private func submitCorrectly(_ viewModel: ExplainViewModel) {
        viewModel.prediction = viewModel.snippet?.expectedOutput ?? ""
        viewModel.explanation = "Because that is what the snippet prints."
        viewModel.submit()
    }

    /// Awaits the session's one inference through the handle the screen would cancel with.
    private func finishGenerating(_ viewModel: ExplainViewModel) async {
        await viewModel.generationTask?.value
    }

    private func notes() throws -> [Note] {
        try container.mainContext.fetch(
            FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt)])
        )
    }

    private func progressRecords() throws -> [ConceptProgress] {
        try container.mainContext.fetch(FetchDescriptor<ConceptProgress>())
    }
}

extension ModelContainer {

    /// A store held entirely in memory, so a test run leaves nothing behind.
    static func inMemoryForTesting() throws -> ModelContainer {
        try ModelContainer(
            for: Note.self, ConceptProgress.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}

extension ContentLibrary {

    /// Two concepts in prerequisite order, each with three snippets authored from least to
    /// most difficult — the authoring contract snippet selection leans on.
    static func practiceFixture() -> ContentLibrary {
        ContentLibrary(
            concepts: [
                fixtureConcept(id: "variables", name: "Variables", position: ConceptPosition(x: 0.3, y: 0.5)),
                fixtureConcept(
                    id: "optionals",
                    name: "Optionals",
                    position: ConceptPosition(x: 0.7, y: 0.5),
                    prerequisites: ["variables"]
                ),
            ],
            snippets: [
                Snippet(id: "variables-1", conceptID: "variables", code: "print(1)", expectedOutput: "1"),
                Snippet(id: "variables-2", conceptID: "variables", code: "print(2)", expectedOutput: "2"),
                Snippet(id: "variables-3", conceptID: "variables", code: "print(3)", expectedOutput: "3"),
                Snippet(id: "optionals-1", conceptID: "optionals", code: "print(age)", expectedOutput: "Optional(5)"),
                Snippet(id: "optionals-2", conceptID: "optionals", code: "print(name)", expectedOutput: "Anonymous"),
                Snippet(id: "optionals-3", conceptID: "optionals", code: "print(score)", expectedOutput: "nil"),
            ]
        )
    }

    private static func fixtureConcept(
        id: String,
        name: String,
        position: ConceptPosition,
        prerequisites: [String] = []
    ) -> Concept {
        Concept(
            id: id,
            name: name,
            summary: "A short frame for \(name.lowercased()).",
            position: position,
            prerequisites: prerequisites,
            related: [],
            rubric: [RubricPoint(number: 1, text: "Something a complete explanation would say.")],
            misconceptions: [
                Misconception(
                    id: "\(id)-misconception",
                    name: "A wrong belief about \(name.lowercased())",
                    correction: "What replaces it."
                )
            ],
            prerequisites: [],
            related: []
        )
    }
}
