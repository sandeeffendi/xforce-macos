//
//  ExplainViewModelTests.swift
//  xforceTests
//

import Foundation
import Testing
@testable import xforce

/// Seam one: the loop, driven through the intent methods a screen would call.
///
/// Output comparison is deliberately not given its own suite. It is an implementation detail
/// of the loop, so the normalisation table below is expressed as sessions driven through the
/// view model — including the cases that must still fail.
@MainActor
struct ExplainViewModelTests {

    // MARK: - Opening on a snippet

    @Test func loadingShowsTheFirstSnippetAndTheConceptItBelongsTo() {
        let viewModel = makeViewModel()

        viewModel.load()

        #expect(viewModel.state == .loaded)
        #expect(viewModel.snippet?.id == "fixture-snippet")
        #expect(viewModel.concept?.id == "optionals")
        #expect(viewModel.concept?.summary.isEmpty == false)
    }

    @Test func loadingUnusableContentFailsWithTheReasonRatherThanAnEmptyScreen() {
        let service = ContentService(library: ContentLibrary(concepts: [], snippets: []))
        let viewModel = ExplainViewModel(content: service)

        viewModel.load()

        #expect(viewModel.state == .failed(ContentError.empty.message))
        #expect(viewModel.snippet == nil)
        #expect(viewModel.canSubmit == false)
    }

    // MARK: - The gate

    @Test func submitIsDisabledUntilBothFieldsCarryContent() {
        let viewModel = makeViewModel()
        viewModel.load()

        #expect(viewModel.canSubmit == false)

        viewModel.prediction = "1"
        #expect(viewModel.canSubmit == false)

        viewModel.prediction = ""
        viewModel.explanation = "It prints one."
        #expect(viewModel.canSubmit == false)

        viewModel.prediction = "1"
        #expect(viewModel.canSubmit)
    }

    @Test func whitespaceAloneDoesNotCountAsContent() {
        let viewModel = makeViewModel()
        viewModel.load()

        viewModel.prediction = "   \n  "
        viewModel.explanation = "\t"

        #expect(viewModel.canSubmit == false)
    }

    @Test func submittingWhileTheControlWouldBeDisabledDoesNothing() {
        let viewModel = makeViewModel()
        viewModel.load()
        viewModel.prediction = "1"

        viewModel.submit()

        #expect(viewModel.phase == .prompt)
        #expect(viewModel.diff == nil)
        #expect(viewModel.outcome == nil)
    }

    @Test func theRealOutputIsUnreachableBeforeTheLearnerCommits() {
        let viewModel = makeViewModel(expectedOutput: "Optional(5)")
        viewModel.load()

        #expect(viewModel.snippet != nil)
        #expect(viewModel.expectedOutput == nil)

        viewModel.prediction = "5"
        viewModel.explanation = "I have not submitted yet."

        #expect(viewModel.expectedOutput == nil)

        viewModel.submit()

        #expect(viewModel.expectedOutput == "Optional(5)")
    }

    @Test func theFeedbackPanelStaysLockedThroughPromptAndReveal() {
        let viewModel = makeViewModel()
        viewModel.load()

        #expect(viewModel.isFeedbackLocked)

        submitCorrectly(viewModel)

        #expect(viewModel.phase == .reveal)
        #expect(viewModel.isFeedbackLocked)
    }

    // MARK: - Ground truth

    @Test func submittingRevealsTheRealOutputAndSaysPlainlyThatTheLearnerWasRight() {
        let viewModel = makeViewModel(expectedOutput: "Optional(5)")
        viewModel.load()
        viewModel.prediction = "Optional(5)"
        viewModel.explanation = "Printing an optional shows the wrapper."

        viewModel.submit()

        #expect(viewModel.phase == .reveal)
        #expect(viewModel.expectedOutput == "Optional(5)")
        #expect(viewModel.outcome == .correct)
    }

    @Test func submittingAWrongPredictionSaysPlainlyThatTheLearnerWasWrong() {
        let viewModel = makeViewModel(expectedOutput: "Optional(5)")
        viewModel.load()
        viewModel.prediction = "5"
        viewModel.explanation = "It prints the number."

        viewModel.submit()

        #expect(viewModel.phase == .reveal)
        #expect(viewModel.outcome == .incorrect)
    }

    // MARK: - The normalisation table

    /// Leading and trailing whitespace is forgiven per line and trailing blank lines are
    /// dropped. Comparison is case-sensitive and interior spacing is preserved.
    @Test(arguments: [
        // Forgiven: nothing about the meaning changed.
        NormalisationCase("Optional(5)", "Optional(5)", .correct, "an exact match"),
        NormalisationCase("  Optional(5)", "Optional(5)", .correct, "leading whitespace"),
        NormalisationCase("Optional(5)   ", "Optional(5)", .correct, "trailing whitespace"),
        NormalisationCase("Optional(5)\n", "Optional(5)", .correct, "one trailing newline"),
        NormalisationCase("Optional(5)\n\n\n", "Optional(5)", .correct, "several trailing blank lines"),
        NormalisationCase("  swift: 9  \n\trust: not rated\t", "swift: 9\nrust: not rated", .correct, "whitespace on every line"),

        // Counted as wrong: the meaning genuinely differs.
        NormalisationCase("5", "Optional(5)", .incorrect, "an unwrapped value where the wrapper was printed"),
        NormalisationCase("True", "true", .incorrect, "a capitalised Python-style boolean"),
        NormalisationCase("FALSE", "false", .incorrect, "an upper-cased boolean"),
        NormalisationCase("Optional(5)", "optional(5)", .incorrect, "a difference of case alone"),
        NormalisationCase("swift:  9", "swift: 9", .incorrect, "widened interior spacing"),
        NormalisationCase("swift:9", "swift: 9", .incorrect, "removed interior spacing"),
        NormalisationCase("rust: not rated\nswift: 9", "swift: 9\nrust: not rated", .incorrect, "lines in the wrong order"),
        NormalisationCase("swift: 9", "swift: 9\nrust: not rated", .incorrect, "a missing line"),
        NormalisationCase("swift: 9\nrust: not rated\nextra", "swift: 9\nrust: not rated", .incorrect, "an extra line"),
        NormalisationCase("swift: 9\n\nrust: not rated", "swift: 9\nrust: not rated", .incorrect, "an interior blank line"),
    ])
    func theNormalisationTableHolds(testCase: NormalisationCase) {
        let viewModel = makeViewModel(expectedOutput: testCase.expected)
        viewModel.load()
        viewModel.prediction = testCase.prediction
        viewModel.explanation = "Because that is what I think it prints."

        viewModel.submit()

        #expect(viewModel.outcome == testCase.outcome, "\(testCase.reason)")
    }

    // MARK: - The diff

    @Test func theDiffMarksOnlyTheLinesThatDiffer() {
        let viewModel = makeViewModel(expectedOutput: "false\n42")
        viewModel.load()
        viewModel.prediction = "false\n41"
        viewModel.explanation = "Int(raw) succeeds so it is not nil."

        viewModel.submit()

        let lines = viewModel.diff?.lines ?? []
        #expect(lines.count == 2)
        #expect(lines.first?.matches == true)
        #expect(lines.last?.matches == false)
        #expect(lines.last?.predicted == "41")
        #expect(lines.last?.expected == "42")
    }

    @Test func theDiffShowsALineTheLearnerDidNotPredictAtAll() {
        let viewModel = makeViewModel(expectedOutput: "swift: 9\nrust: not rated")
        viewModel.load()
        viewModel.prediction = "swift: 9"
        viewModel.explanation = "Only the first lookup succeeds."

        viewModel.submit()

        let lines = viewModel.diff?.lines ?? []
        #expect(lines.count == 2)
        #expect(lines.last?.predicted == nil)
        #expect(lines.last?.expected == "rust: not rated")
        #expect(viewModel.diff?.isCorrect == false)
    }

    @Test func theDiffShowsALineTheLearnerPredictedButTheSnippetNeverPrints() {
        let viewModel = makeViewModel(expectedOutput: "swift: 9")
        viewModel.load()
        viewModel.prediction = "swift: 9\nrust: not rated"
        viewModel.explanation = "I think both branches run."

        viewModel.submit()

        let lines = viewModel.diff?.lines ?? []
        #expect(lines.count == 2)
        #expect(lines.last?.predicted == "rust: not rated")
        #expect(lines.last?.expected == nil)
    }

    @Test func theDiffPreservesInteriorSpacingSoTheLearnerCanSeeWhereItBroke() {
        let viewModel = makeViewModel(expectedOutput: "swift: 9")
        viewModel.load()
        viewModel.prediction = "swift:  9"
        viewModel.explanation = "Two spaces after the colon."

        viewModel.submit()

        #expect(viewModel.diff?.lines.first?.predicted == "swift:  9")
    }

    // MARK: - Forward-only phases

    @Test func theLoopStartsAtPrompt() {
        let viewModel = makeViewModel()

        #expect(viewModel.phase == .prompt)
    }

    @Test func submittingTwiceNeverReRunsTheReveal() {
        let viewModel = makeViewModel(expectedOutput: "Optional(5)")
        viewModel.load()
        viewModel.prediction = "Optional(5)"
        viewModel.explanation = "The wrapper is printed."
        viewModel.submit()

        viewModel.prediction = "5"
        viewModel.submit()

        #expect(viewModel.phase == .reveal)
        #expect(viewModel.outcome == .correct)
    }

    @Test func editingTheFieldsAfterTheRevealCannotReturnTheLoopToPrompt() {
        let viewModel = makeViewModel()
        viewModel.load()
        submitCorrectly(viewModel)

        viewModel.prediction = ""
        viewModel.explanation = ""

        #expect(viewModel.phase == .reveal)
        #expect(viewModel.canSubmit == false)
    }

    @Test func loadingAgainDoesNotRewindALoopThatHasAlreadyRevealed() {
        let viewModel = makeViewModel()
        viewModel.load()
        submitCorrectly(viewModel)

        viewModel.load()

        #expect(viewModel.phase == .reveal)
        #expect(viewModel.diff != nil)
    }

    // MARK: - Helpers

    private func makeViewModel(expectedOutput: String = "1") -> ExplainViewModel {
        let library = ContentLibrary.fixture(code: "print(1)", expectedOutput: expectedOutput)
        return ExplainViewModel(content: ContentService(library: library))
    }

    private func submitCorrectly(_ viewModel: ExplainViewModel) {
        viewModel.prediction = viewModel.snippet?.expectedOutput ?? ""
        viewModel.explanation = "Because that is what the snippet prints."
        viewModel.submit()
    }
}

/// One row of the normalisation table.
nonisolated struct NormalisationCase: Sendable, CustomTestStringConvertible {
    let prediction: String
    let expected: String
    let outcome: PredictionOutcome
    let reason: String

    init(_ prediction: String, _ expected: String, _ outcome: PredictionOutcome, _ reason: String) {
        self.prediction = prediction
        self.expected = expected
        self.outcome = outcome
        self.reason = reason
    }

    var testDescription: String { "\(reason) is \(outcome)" }
}

@Suite
struct LoopPhaseTests {

    @Test func thePhasesAreOrderedSoATransitionCanOnlyMoveForward() {
        #expect(LoopPhase.prompt < .reveal)
        #expect(LoopPhase.reveal < .socratic)
        #expect(LoopPhase.socratic < .feedback)
        #expect(LoopPhase.feedback < .committed)
    }

    @Test func theFeedbackPanelIsLockedUntilTheFeedbackPhase() {
        #expect(LoopPhase.prompt.isFeedbackUnlocked == false)
        #expect(LoopPhase.reveal.isFeedbackUnlocked == false)
        #expect(LoopPhase.socratic.isFeedbackUnlocked == false)
        #expect(LoopPhase.feedback.isFeedbackUnlocked)
        #expect(LoopPhase.committed.isFeedbackUnlocked)
    }
}
