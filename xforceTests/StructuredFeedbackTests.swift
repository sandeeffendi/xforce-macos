//
//  StructuredFeedbackTests.swift
//  xforceTests
//

import Foundation
import SwiftData
import Testing
@testable import xforce

/// Seam one again: the structured panel, driven through the intent methods a screen calls.
///
/// Nothing here asserts on model prose. The model contributes exactly two things — a set of
/// rubric numbers and a set of misconception cases — and every assertion below is a set
/// comparison over those, which is the whole reason the generated type was kept this small.
@MainActor
struct StructuredFeedbackTests {

    // MARK: - What the learner got right, and what is missing

    @Test func whatTheLearnerGotRightIsWhatTheModelNamedAndWhatIsMissingIsEverythingElse() async throws {
        let (viewModel, _) = makeLoop(covered: [1, 3])

        await reachFeedback(viewModel)

        let feedback = try #require(viewModel.structuredFeedback)
        #expect(feedback.covered.map(\.number) == [1, 3])
        #expect(feedback.missing.map(\.number) == [2, 4, 5])
    }

    @Test func theMissingPointsCarryTheWordingTheLearnerHasToAddress() async throws {
        let (viewModel, _) = makeLoop(covered: [1, 2, 3, 4])

        await reachFeedback(viewModel)

        let feedback = try #require(viewModel.structuredFeedback)
        #expect(feedback.missing.map(\.text) == ["Force unwrapping nil stops the program."])
    }

    /// The complement is the whole point of computing rather than generating: whatever the
    /// model names, the two lists partition the rubric exactly once.
    @Test(arguments: [[Int](), [1], [2, 4], [1, 2, 3, 4, 5], [3, 1], [0, 9, 2]])
    func aPointIsNeverBothCoveredAndMissing(covered: [Int]) async throws {
        let (viewModel, _) = makeLoop(covered: covered)

        await reachFeedback(viewModel)

        let feedback = try #require(viewModel.structuredFeedback)
        let coveredNumbers = Set(feedback.covered.map(\.number))
        let missingNumbers = Set(feedback.missing.map(\.number))

        #expect(coveredNumbers.isDisjoint(with: missingNumbers))
        #expect(coveredNumbers.union(missingNumbers) == Set(1...5))
        #expect(feedback.covered.count + feedback.missing.count == 5)
    }

    @Test func rubricNumbersTheConceptDoesNotHaveAreDiscardedRatherThanRendered() async throws {
        let (viewModel, _) = makeLoop(covered: [-1, 0, 2, 5, 6, 99])

        await reachFeedback(viewModel)

        let feedback = try #require(viewModel.structuredFeedback)
        #expect(feedback.covered.map(\.number) == [2, 5])
        #expect(feedback.missing.map(\.number) == [1, 3, 4])
    }

    @Test func thePointsAreShownInTheirAuthoredOrderHoweverTheModelOrderedThem() async throws {
        let (viewModel, _) = makeLoop(covered: [5, 1, 3, 1])

        await reachFeedback(viewModel)

        let feedback = try #require(viewModel.structuredFeedback)
        #expect(feedback.covered.map(\.number) == [1, 3, 5])
        #expect(feedback.missing.map(\.number) == [2, 4])
    }

    // MARK: - Misconceptions

    @Test func aDetectedMisconceptionIsNamedAndCorrected() async throws {
        let (viewModel, _) = makeLoop(misconceptions: [.printingShowsTheValue])

        await reachFeedback(viewModel)

        let feedback = try #require(viewModel.structuredFeedback)
        let misconception = try #require(feedback.misconceptions.first)
        #expect(feedback.misconceptions.count == 1)
        #expect(misconception.id == MisconceptionID.printingShowsTheValue.rawValue)
        #expect(misconception.name.isEmpty == false)
        #expect(misconception.correction.isEmpty == false)
    }

    @Test func aMisconceptionThatBelongsToAnotherConceptIsDiscarded() async throws {
        let (viewModel, _) = makeLoop(misconceptions: [.nilCoalescingUnwrapsPermanently])

        await reachFeedback(viewModel)

        let feedback = try #require(viewModel.structuredFeedback)
        #expect(feedback.misconceptions.isEmpty)
    }

    @Test func onlyTheMisconceptionsThisConceptOwnsSurvive() async throws {
        let (viewModel, _) = makeLoop(
            misconceptions: [.nilCoalescingUnwrapsPermanently, .printingShowsTheValue, .nilIsZeroOrEmpty]
        )

        await reachFeedback(viewModel)

        let feedback = try #require(viewModel.structuredFeedback)
        #expect(feedback.misconceptions.map(\.id) == [MisconceptionID.printingShowsTheValue.rawValue])
    }

    @Test func theSameMisconceptionReportedTwiceIsShownOnce() async throws {
        let (viewModel, _) = makeLoop(misconceptions: [.printingShowsTheValue, .printingShowsTheValue])

        await reachFeedback(viewModel)

        let feedback = try #require(viewModel.structuredFeedback)
        #expect(feedback.misconceptions.count == 1)
    }

    @Test func nothingDetectedMeansThereIsNoMisconceptionSectionToShow() async throws {
        let (viewModel, _) = makeLoop(misconceptions: [])

        await reachFeedback(viewModel)

        let feedback = try #require(viewModel.structuredFeedback)
        #expect(feedback.misconceptions.isEmpty)
    }

    // MARK: - The concepts this one connects to

    /// Authored edges, resolved against the ontology. The model is never asked, so there is
    /// nothing here for it to drift on.
    @Test func theConceptsThisOneConnectsToComeFromTheOntologyRatherThanFromTheModel() async {
        let (viewModel, service) = makeLoop()

        await reachFeedback(viewModel)

        #expect(viewModel.connectedConcepts.map(\.id) == ["variables", "closures"])
        #expect(viewModel.connectedConcepts.map(\.name) == ["Variables", "Closures"])
        #expect(service.calls.inferences == 1)
    }

    @Test func anEdgeNamingAConceptTheOntologyDoesNotHaveIsDropped() async {
        let (viewModel, _) = makeLoop()

        await reachFeedback(viewModel)

        #expect(viewModel.connectedConcepts.contains { $0.id == "vanished-concept" } == false)
    }

    @Test func aConceptIsNeverListedAsConnectedToItself() async {
        let (viewModel, _) = makeLoop()

        await reachFeedback(viewModel)

        #expect(viewModel.connectedConcepts.contains { $0.id == "optionals" } == false)
    }

    @Test func theConnectionsAreWithheldUntilTheGateOpensLikeEverythingElse() async {
        let (viewModel, _) = makeLoop()
        viewModel.load()

        #expect(viewModel.connectedConcepts.isEmpty)

        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        #expect(viewModel.phase == .socratic)
        #expect(viewModel.connectedConcepts.isEmpty)

        viewModel.skip()

        #expect(viewModel.connectedConcepts.isEmpty == false)
    }

    /// The section that needs no model has to survive not having one, or graceful degradation
    /// would stop at the panel's edge.
    @Test func theConnectionsSurviveAMacWithNoModelToAsk() async {
        let (viewModel, _) = makeLoop(availability: .deviceNotEligible)
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        #expect(viewModel.phase == .feedback)
        #expect(viewModel.structuredFeedback == nil)
        #expect(viewModel.connectedConcepts.map(\.id) == ["variables", "closures"])
    }

    // MARK: - The gate

    @Test func theStructuredFeedbackIsUnreachableUntilTheQuestionIsAnsweredOrSkipped() async {
        let (viewModel, _) = makeLoop(covered: [1])
        viewModel.load()

        #expect(viewModel.structuredFeedback == nil)

        submitCorrectly(viewModel)
        #expect(viewModel.structuredFeedback == nil)

        await finishGenerating(viewModel)
        #expect(viewModel.phase == .socratic)
        #expect(viewModel.structuredFeedback == nil)

        viewModel.answer()
        #expect(viewModel.structuredFeedback != nil)
    }

    @Test func skippingTheQuestionUnlocksTheSamePanelAnsweringWouldHave() async throws {
        let (viewModel, _) = makeLoop(covered: [2])
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        viewModel.skip()

        let feedback = try #require(viewModel.structuredFeedback)
        #expect(feedback.covered.map(\.number) == [2])
    }

    @Test func aNewSnippetStartsWithAnEmptyPanel() async throws {
        let (viewModel, _) = makeLoop(covered: [1])
        await reachFeedback(viewModel)
        viewModel.commit()

        viewModel.startNextSnippet()

        #expect(viewModel.phase == .prompt)
        #expect(viewModel.structuredFeedback == nil)
    }

    // MARK: - Degradation

    @Test(arguments: [
        FeedbackAvailability.deviceNotEligible,
        .appleIntelligenceNotEnabled,
        .modelNotReady,
    ])
    func withNoModelThereIsNoPanelContentButTheLoopStillReachesTheCommit(
        reason: FeedbackAvailability
    ) async {
        let (viewModel, _) = makeLoop(availability: reason)
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        #expect(viewModel.phase == .feedback)
        #expect(viewModel.structuredFeedback == nil)
        #expect(viewModel.canCommit)
    }

    @Test func aFailedGenerationLeavesNoPanelContentAndDoesNotBlockTheCommit() async {
        let (viewModel, _) = makeLoop(behaviour: .fails(.explanationTooLong))
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        #expect(viewModel.structuredFeedback == nil)
        #expect(viewModel.canCommit)
    }

    @Test func aCancelledGenerationLeavesNoPanelContent() async {
        let (viewModel, _) = makeLoop(behaviour: .hangs)
        viewModel.load()
        submitCorrectly(viewModel)

        viewModel.cancelGenerating()

        #expect(viewModel.phase == .feedback)
        #expect(viewModel.structuredFeedback == nil)
        #expect(viewModel.canCommit)
    }

    // MARK: - Helpers

    private func makeLoop(
        covered: [Int] = [],
        misconceptions: [MisconceptionID] = [],
        availability: FeedbackAvailability = .available,
        behaviour: FakeFeedbackService.Behaviour? = nil
    ) -> (ExplainViewModel, FakeFeedbackService) {
        let service = FakeFeedbackService(
            availability: availability,
            behaviour: behaviour ?? .returns(
                ExplanationFeedback(
                    socraticQuestion: FakeFeedbackService.defaultQuestion,
                    coveredRubricPoints: covered,
                    misconceptions: misconceptions
                )
            )
        )
        return (
            ExplainViewModel(
                content: ContentService(library: .feedbackFixture()),
                feedback: service,
                scheduling: .inMemory()
            ),
            service
        )
    }

    private func reachFeedback(_ viewModel: ExplainViewModel) async {
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)
        viewModel.skip()
    }

    private func submitCorrectly(_ viewModel: ExplainViewModel) {
        viewModel.prediction = viewModel.snippet?.expectedOutput ?? ""
        viewModel.explanation = "Because that is what the snippet prints."
        viewModel.submit()
    }

    private func finishGenerating(_ viewModel: ExplainViewModel) async {
        await viewModel.generationTask?.value
    }
}

/// What a detected misconception does to the schedule, and what it can never do.
@MainActor
struct FeedbackOutcomeTests {

    private let container: ModelContainer
    private let scheduling: SchedulingService

    init() throws {
        container = try ModelContainer.inMemoryForTesting()
        scheduling = SchedulingService(container: container)
    }

    @Test func aCorrectPredictionWithNoMisconceptionAdvancesTheConcept() async throws {
        let viewModel = makeViewModel()
        await reachFeedback(viewModel, predictingCorrectly: true)

        viewModel.commit()

        #expect(try note().outcome == .mastered)
        #expect(viewModel.progress?.box == 2)
    }

    @Test func aCorrectPredictionWithADetectedMisconceptionHoldsTheConceptInItsBox() async throws {
        let viewModel = makeViewModel(misconceptions: [.printingShowsTheValue])
        await reachFeedback(viewModel, predictingCorrectly: true)

        viewModel.commit()

        #expect(try note().outcome == .fragile)
        #expect(viewModel.progress?.box == 1)
    }

    /// The filtering is what decides this, so a misconception the concept does not own must
    /// not quietly downgrade a clean session.
    @Test func aMisconceptionThisConceptDoesNotOwnCannotMakeASessionFragile() async throws {
        let viewModel = makeViewModel(misconceptions: [.nilCoalescingUnwrapsPermanently])
        await reachFeedback(viewModel, predictingCorrectly: true)

        viewModel.commit()

        #expect(try note().outcome == .mastered)
        #expect(viewModel.progress?.box == 2)
    }

    @Test func aWrongPredictionFailsWhateverTheModelReported() async throws {
        let viewModel = makeViewModel(misconceptions: [.printingShowsTheValue])
        await reachFeedback(viewModel, predictingCorrectly: false)

        viewModel.commit()

        #expect(try note().outcome == .failed)
    }

    /// The rule the whole design rests on, stated exhaustively rather than by example:
    /// `failed` follows from the output comparison and from nothing else.
    @Test(arguments: [PredictionOutcome.correct, .incorrect], [true, false])
    func theModelCanNeverCauseAFailedOutcome(
        outcome: PredictionOutcome,
        misconceptionDetected: Bool
    ) {
        let session = outcome.sessionOutcome(misconceptionDetected: misconceptionDetected)

        #expect((session == .failed) == (outcome == .incorrect))
    }

    @Test func theOutcomeMovesBetweenMasteredAndFragileAndNowhereElse() {
        #expect(PredictionOutcome.correct.sessionOutcome(misconceptionDetected: false) == .mastered)
        #expect(PredictionOutcome.correct.sessionOutcome(misconceptionDetected: true) == .fragile)
        #expect(PredictionOutcome.incorrect.sessionOutcome(misconceptionDetected: false) == .failed)
        #expect(PredictionOutcome.incorrect.sessionOutcome(misconceptionDetected: true) == .failed)
    }

    /// The note is the record of the session, so what the model judged has to be in it — the
    /// panel is a rendering of the note, not the only place the judgement exists.
    @Test func theNoteRecordsWhatTheModelJudgedAlongsideWhatTheLearnerWrote() async throws {
        let viewModel = makeViewModel(covered: [1, 3], misconceptions: [.printingShowsTheValue])
        await reachFeedback(viewModel, predictingCorrectly: true)

        viewModel.commit()

        let note = try note()
        #expect(note.coveredRubricPoints == [1, 3])
        #expect(note.detectedMisconceptionIDs == [MisconceptionID.printingShowsTheValue.rawValue])
        #expect(note.socraticQuestion == FakeFeedbackService.defaultQuestion)
        #expect(note.explanation == "Because that is what the snippet prints.")
    }

    @Test func aSessionWithNoModelRecordsNoJudgementAtAll() throws {
        let viewModel = makeViewModel(availability: .deviceNotEligible)
        viewModel.load()
        viewModel.prediction = viewModel.snippet?.expectedOutput ?? ""
        viewModel.explanation = "Because that is what the snippet prints."
        viewModel.submit()

        viewModel.commit()

        let note = try note()
        #expect(note.coveredRubricPoints.isEmpty)
        #expect(note.detectedMisconceptionIDs.isEmpty)
        #expect(note.outcome == .mastered)
    }

    // MARK: - Helpers

    private func makeViewModel(
        covered: [Int] = [],
        misconceptions: [MisconceptionID] = [],
        availability: FeedbackAvailability = .available
    ) -> ExplainViewModel {
        ExplainViewModel(
            content: ContentService(library: .feedbackFixture()),
            feedback: FakeFeedbackService(
                availability: availability,
                behaviour: .returns(
                    ExplanationFeedback(
                        socraticQuestion: FakeFeedbackService.defaultQuestion,
                        coveredRubricPoints: covered,
                        misconceptions: misconceptions
                    )
                )
            ),
            scheduling: scheduling
        )
    }

    private func reachFeedback(
        _ viewModel: ExplainViewModel,
        predictingCorrectly correctly: Bool
    ) async {
        viewModel.load()
        viewModel.prediction = correctly ? (viewModel.snippet?.expectedOutput ?? "") : "not that"
        viewModel.explanation = "Because that is what the snippet prints."
        viewModel.submit()
        await viewModel.generationTask?.value
        viewModel.skip()
    }

    private func note() throws -> Note {
        let written = try container.mainContext.fetch(
            FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt)])
        )
        return try #require(written.last)
    }
}

extension ContentLibrary {

    /// One concept with a five-point rubric, two curated misconceptions and authored edges —
    /// including one that cannot be resolved and one that points back at itself, so the rules
    /// that drop those have something to drop.
    ///
    /// Its misconception ids are real ones from the shipped ontology, because the closed
    /// generated type the model answers with is the shipped ontology's ids and nothing else.
    static func feedbackFixture() -> ContentLibrary {
        ContentLibrary(
            concepts: [
                Concept(
                    id: "optionals",
                    name: "Optionals",
                    summary: "A value that may be absent.",
                    position: ConceptPosition(x: 0.5, y: 0.5),
                    prerequisites: ["variables"],
                    related: ["closures", "optionals", "vanished-concept"],
                    rubric: [
                        RubricPoint(number: 1, text: "An optional either holds a value or holds nil."),
                        RubricPoint(number: 2, text: "Printing an optional shows the wrapper."),
                        RubricPoint(number: 3, text: "The value has to be unwrapped before it is used."),
                        RubricPoint(number: 4, text: "`??` supplies a fallback for the nil case."),
                        RubricPoint(number: 5, text: "Force unwrapping nil stops the program."),
                    ],
                    misconceptions: [
                        Misconception(
                            id: MisconceptionID.printingShowsTheValue.rawValue,
                            name: "Printing an optional prints the value it holds",
                            correction: "Printing an optional shows the Optional(...) wrapper."
                        ),
                        Misconception(
                            id: MisconceptionID.optionalIsTheSameAsTheValue.rawValue,
                            name: "An optional can be used wherever the underlying value can",
                            correction: "`Int?` and `Int` are distinct types."
                        ),
                    ]
                ),
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
                            id: MisconceptionID.nilIsZeroOrEmpty.rawValue,
                            name: "nil is the same as 0",
                            correction: "nil means there is no value at all."
                        )
                    ]
                ),
                Concept(
                    id: "closures",
                    name: "Closures",
                    summary: "A function that captures its surroundings.",
                    position: ConceptPosition(x: 0.8, y: 0.5),
                    prerequisites: [],
                    related: [],
                    rubric: [RubricPoint(number: 1, text: "A closure captures by reference.")],
                    misconceptions: [
                        Misconception(
                            id: MisconceptionID.nilCoalescingUnwrapsPermanently.rawValue,
                            name: "`??` unwraps everywhere",
                            correction: "`??` produces a non-optional result for that expression only."
                        )
                    ]
                ),
            ],
            snippets: [
                Snippet(
                    id: "optionals-1",
                    conceptID: "optionals",
                    code: "print(age)",
                    expectedOutput: "Optional(5)"
                ),
                Snippet(
                    id: "optionals-2",
                    conceptID: "optionals",
                    code: "print(name)",
                    expectedOutput: "Anonymous"
                ),
            ]
        )
    }
}
