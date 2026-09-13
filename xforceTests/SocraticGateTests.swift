//
//  SocraticGateTests.swift
//  xforceTests
//

import Foundation
import Testing
@testable import xforce

/// Seam three: the gate, and the one inference behind it.
///
/// Everything here is driven through the fake conformance, so the suite asserts the rules
/// the design turns on — that the panel cannot be reached early, that the session makes
/// exactly one inference, that the learner's answer changes nothing, and that a Mac with no
/// model still gets through the loop — rather than asserting on model output.
@MainActor
struct SocraticGateTests {

    // MARK: - The gate

    @Test func theFeedbackStaysLockedUntilTheQuestionHasBeenAnsweredOrSkipped() async {
        let (viewModel, _) = makeLoop()
        viewModel.load()

        #expect(viewModel.isFeedbackLocked)

        submitCorrectly(viewModel)
        #expect(viewModel.isFeedbackLocked)

        await finishGenerating(viewModel)
        #expect(viewModel.phase == .socratic)
        #expect(viewModel.isFeedbackLocked)

        viewModel.answer()
        #expect(viewModel.phase == .feedback)
        #expect(viewModel.isFeedbackLocked == false)
    }

    @Test func theQuestionIsUnreachableBeforeTheLearnerCommits() async {
        let (viewModel, service) = makeLoop()
        viewModel.load()

        #expect(viewModel.socraticQuestion == nil)
        #expect(viewModel.generation == .idle)
        #expect(service.calls.inferences == 0)

        viewModel.prediction = "1"
        viewModel.explanation = "I have not submitted yet."

        #expect(viewModel.socraticQuestion == nil)
        #expect(service.calls.inferences == 0)
    }

    @Test func answeringBeforeTheQuestionArrivesCannotMoveTheLoop() {
        let (viewModel, _) = makeLoop()
        viewModel.load()

        viewModel.socraticAnswer = "Trying to get ahead."
        viewModel.answer()
        viewModel.skip()

        #expect(viewModel.phase == .prompt)
        #expect(viewModel.socraticResponse == nil)
        #expect(viewModel.isFeedbackLocked)
    }

    @Test func theInspectorIsOnScreenOnlyOnceThereIsSomethingToPractise() {
        let (viewModel, _) = makeLoop()

        #expect(viewModel.isInspectorVisible == false)

        viewModel.load()

        #expect(viewModel.isInspectorVisible)
        #expect(viewModel.isFeedbackLocked)
    }

    // MARK: - Exactly one inference

    @Test func aSessionMakesExactlyOneInference() async {
        let (viewModel, service) = makeLoop()
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        viewModel.socraticAnswer = "Because the wrapper is printed, not the value."
        viewModel.answer()

        #expect(service.calls.inferences == 1)
    }

    @Test func submittingTwiceNeverAsksTheModelASecondTime() async {
        let (viewModel, service) = makeLoop()
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        viewModel.prediction = "something else"
        viewModel.submit()
        await finishGenerating(viewModel)

        #expect(service.calls.inferences == 1)
    }

    @Test func theOneInferenceIsGivenTheLearnersOwnExplanation() async {
        let (viewModel, service) = makeLoop()
        viewModel.load()
        viewModel.prediction = "1"
        viewModel.explanation = "Because print writes the value straight out."
        viewModel.submit()
        await finishGenerating(viewModel)

        #expect(service.calls.lastExplanation == "Because print writes the value straight out.")
        #expect(service.calls.lastConceptID == "optionals")
        #expect(service.calls.lastSnippetID == "fixture-snippet")
    }

    // MARK: - The question, on its own

    @Test func afterTheRevealTheQuestionIsTheOnlyModelOutputThereIs() async {
        let (viewModel, _) = makeLoop(question: "What told you the wrapper would be gone?")
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        #expect(viewModel.phase == .socratic)
        #expect(viewModel.socraticQuestion == "What told you the wrapper would be gone?")
        #expect(viewModel.generation == .asked("What told you the wrapper would be gone?"))
        #expect(viewModel.isFeedbackLocked)
    }

    // MARK: - Answering and skipping

    @Test func anAnswerIsRecordedAsEvidenceOfTheLearnersThinking() async {
        let (viewModel, _) = makeLoop()
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        viewModel.socraticAnswer = "  I had forgotten the wrapper survives printing.  "
        viewModel.answer()

        #expect(viewModel.socraticResponse == .answered("I had forgotten the wrapper survives printing."))
        #expect(viewModel.phase == .feedback)
    }

    @Test func aSkipIsRecordedDistinctlyFromAnEmptyAnswer() async {
        let (skipping, _) = makeLoop()
        skipping.load()
        submitCorrectly(skipping)
        await finishGenerating(skipping)
        skipping.skip()

        let (answering, _) = makeLoop()
        answering.load()
        submitCorrectly(answering)
        await finishGenerating(answering)
        answering.socraticAnswer = "   "
        answering.answer()

        #expect(skipping.socraticResponse == .skipped)
        #expect(answering.socraticResponse == .answered(""))
        #expect(skipping.socraticResponse != answering.socraticResponse)
        #expect(skipping.phase == .feedback)
        #expect(answering.phase == .feedback)
    }

    @Test func theAnswerIsRecordedOnceAndCannotBeRewritten() async {
        let (viewModel, _) = makeLoop()
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        viewModel.socraticAnswer = "First thought."
        viewModel.answer()

        viewModel.socraticAnswer = "Second, better thought."
        viewModel.answer()
        viewModel.skip()

        #expect(viewModel.socraticResponse == .answered("First thought."))
    }

    @Test func theAnswerFeedsNothing() async {
        let (viewModel, service) = makeLoop()
        viewModel.load()
        viewModel.prediction = "1"
        viewModel.explanation = "It prints one."
        viewModel.submit()
        await finishGenerating(viewModel)

        let outcomeBefore = viewModel.outcome
        let diffBefore = viewModel.diff

        viewModel.socraticAnswer = "Actually I now think it prints something else entirely."
        viewModel.answer()

        #expect(viewModel.outcome == outcomeBefore)
        #expect(viewModel.diff == diffBefore)
        #expect(service.calls.inferences == 1)
    }

    // MARK: - Prewarming

    @Test func typingTheExplanationPrewarmsTheModelExactlyOnce() {
        let (viewModel, service) = makeLoop()
        viewModel.load()

        #expect(service.calls.prewarms == 0)

        viewModel.explanation = "B"
        viewModel.explanation = "Be"
        viewModel.explanation = "Bec"

        #expect(service.calls.prewarms == 1)
    }

    @Test func typingThePredictionDoesNotPrewarmTheModel() {
        let (viewModel, service) = makeLoop()
        viewModel.load()

        viewModel.prediction = "Optional(5)"

        #expect(service.calls.prewarms == 0)
    }

    @Test func anUnavailableModelIsNeverPrewarmed() {
        let (viewModel, service) = makeLoop(availability: .appleIntelligenceNotEnabled)
        viewModel.load()

        viewModel.explanation = "Typing away."

        #expect(service.calls.prewarms == 0)
    }

    // MARK: - Progress and cancellation

    @Test func theGenerationReportsThatItIsWorking() {
        let (viewModel, _) = makeLoop(behaviour: .hangs)
        viewModel.load()
        submitCorrectly(viewModel)

        #expect(viewModel.generation == .running)
        #expect(viewModel.isGenerating)
        #expect(viewModel.phase == .reveal)
    }

    @Test func aSlowGenerationCanBeCancelledAndTheLoopStillMovesOn() async {
        let (viewModel, _) = makeLoop(behaviour: .hangs)
        viewModel.load()
        submitCorrectly(viewModel)

        viewModel.cancelGenerating()

        #expect(viewModel.generation == .cancelled)
        #expect(viewModel.isGenerating == false)
        #expect(viewModel.phase == .feedback)
        #expect(viewModel.socraticQuestion == nil)

        // The cancelled task must not come back and overwrite what the learner was shown.
        await finishGenerating(viewModel)
        #expect(viewModel.generation == .cancelled)
    }

    @Test func cancellingWhenNothingIsRunningDoesNothing() async {
        let (viewModel, _) = makeLoop()
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        viewModel.cancelGenerating()

        #expect(viewModel.generation == .asked(FakeFeedbackService.defaultQuestion))
        #expect(viewModel.phase == .socratic)
    }

    // MARK: - Availability, as a first-class path

    @Test(arguments: [
        FeedbackAvailability.deviceNotEligible,
        .appleIntelligenceNotEnabled,
        .modelNotReady,
    ])
    func anUnavailableModelDisablesTheQuestioningAndNothingElse(reason: FeedbackAvailability) async {
        let (viewModel, service) = makeLoop(availability: reason)
        viewModel.load()
        viewModel.prediction = "1"
        viewModel.explanation = "It prints one."
        viewModel.submit()
        await finishGenerating(viewModel)

        // The deterministic half of the loop is untouched.
        #expect(viewModel.expectedOutput == "1")
        #expect(viewModel.outcome == .correct)
        #expect(viewModel.diff != nil)

        // The questioning is what is missing, and it says why.
        #expect(service.calls.inferences == 0)
        #expect(viewModel.socraticQuestion == nil)
        #expect(viewModel.generation == .unavailable(reason))
        #expect(viewModel.availability == reason)

        // And the loop is not left stranded short of the commit.
        #expect(viewModel.phase == .feedback)
    }

    @Test func everyUnavailabilityReasonCarriesItsOwnMessage() {
        let reasons: [FeedbackAvailability] = [
            .deviceNotEligible,
            .appleIntelligenceNotEnabled,
            .modelNotReady,
        ]

        let messages = reasons.compactMap(\.message)

        #expect(messages.count == reasons.count)
        #expect(Set(messages).count == reasons.count)
        #expect(FeedbackAvailability.available.message == nil)
        #expect(FeedbackAvailability.available.isAvailable)
    }

    // MARK: - Failure

    @Test func anExplanationTooLongForTheModelIsReportedAsTooLong() async {
        let (viewModel, _) = makeLoop(behaviour: .fails(.explanationTooLong))
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        #expect(viewModel.generation == .failed(FeedbackError.explanationTooLong.message))
        #expect(viewModel.generation != .failed(FeedbackError.generationFailed("boom").message))
        #expect(viewModel.phase == .feedback)
    }

    @Test func theTooLongMessageTalksAboutLengthRatherThanAboutAFailure() {
        let message = FeedbackError.explanationTooLong.message

        #expect(message.localizedCaseInsensitiveContains("long"))
        #expect(message.localizedCaseInsensitiveContains("shorter"))
    }

    @Test func aFailedGenerationExplainsItselfAndLetsTheLoopContinue() async {
        let (viewModel, _) = makeLoop(behaviour: .fails(.generationFailed("the model gave up")))
        viewModel.load()
        submitCorrectly(viewModel)
        await finishGenerating(viewModel)

        #expect(viewModel.generation == .failed(FeedbackError.generationFailed("the model gave up").message))
        #expect(viewModel.socraticQuestion == nil)
        #expect(viewModel.phase == .feedback)
        #expect(viewModel.outcome != nil)
    }

    // MARK: - Helpers

    private func makeLoop(
        availability: FeedbackAvailability = .available,
        behaviour: FakeFeedbackService.Behaviour? = nil,
        question: String = FakeFeedbackService.defaultQuestion,
        expectedOutput: String = "1"
    ) -> (ExplainViewModel, FakeFeedbackService) {
        let service = FakeFeedbackService(
            availability: availability,
            behaviour: behaviour ?? .answers(question)
        )
        let content = ContentService(
            library: .fixture(code: "print(1)", expectedOutput: expectedOutput)
        )
        return (
            ExplainViewModel(content: content, feedback: service, scheduling: .inMemory()),
            service
        )
    }

    private func submitCorrectly(_ viewModel: ExplainViewModel) {
        viewModel.prediction = viewModel.snippet?.expectedOutput ?? ""
        viewModel.explanation = "Because that is what the snippet prints."
        viewModel.submit()
    }

    /// Awaits the session's one inference. The view model keeps the task so the screen can
    /// cancel it; a test borrows the same handle rather than polling.
    private func finishGenerating(_ viewModel: ExplainViewModel) async {
        await viewModel.generationTask?.value
    }
}
