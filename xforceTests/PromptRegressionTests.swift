//
//  PromptRegressionTests.swift
//  xforceTests
//

import Foundation
import Testing
@testable import xforce

// MARK: - Running this suite
//
// The on-device model is not a fixed dependency. It is replaced by operating system updates
// the learner installs on their own schedule, and when it changes, the prompt can start
// producing different judgements with no error, no warning and no failing build. This suite
// is the early warning: six authored learner explanations, run through the real model, with
// set comparisons over the rubric points it reports as covered and the misconceptions it
// reports as detected. The Socratic question's wording is never asserted on — only that one
// came back at all.
//
// It is **excluded from the default test run** and only runs when `XFORCE_PROMPT_REGRESSION`
// is set in the environment of the process the tests run in:
//
//     # default run — this suite is skipped, everything else runs
//     xcodebuild -project xforce.xcodeproj -scheme xforce \
//       -derivedDataPath .build/DerivedData test
//
//     # real inference, this suite only
//     TEST_RUNNER_XFORCE_PROMPT_REGRESSION=1 \
//       xcodebuild -project xforce.xcodeproj -scheme xforce \
//       -derivedDataPath .build/DerivedData -parallel-testing-enabled NO \
//       test -only-testing:xforceTests/PromptRegressionTests
//
// The `TEST_RUNNER_` prefix is not decoration and the suite will not run without it: the test
// host does not inherit the shell's environment, and `xcodebuild` forwards only the variables
// named that way, stripping the prefix so the suite sees plain `XFORCE_PROMPT_REGRESSION`.
// From Xcode, put `XFORCE_PROMPT_REGRESSION` in the test action's environment instead.
// `docs/system-design.md` carries the same invocation and the rest of the reasoning.
//
// Three reasons for the gate, and all three matter: it needs a Mac eligible for Apple
// Intelligence with the model downloaded, it spends real inference time per fixture, and the
// model is not deterministic. The project's rule is that nothing is reported as working
// without a green test run, and a default run that cannot pass on an ineligible Mac would make
// that rule impossible to honour.
//
// ## What it found the first time it was run
//
// Not a green baseline. On macOS 26.6.2 with the model available, the shipped prompt did not
// match these expectations on any fixture, and the two gaps were consistent across runs: the
// model credits fewer rubric points than the learner's words actually cover, and it reports
// misconceptions that the explanation does not show — including, on one run, a misconception
// belonging to an entirely different concept. The per-run numbers are recorded on issue #10
// rather than here, where they would go stale.
//
// That is a finding about the prompt, not a reason to move the expectations. Read the next
// section as written: it applies to the first failure as much as to the hundredth.
//
// ## When it fails after an operating system update
//
// **Re-examine the prompt. Do not loosen the assertions.** The expectations in
// `PromptRegressionFixtures.swift` are a human judgement about what correct feedback on a
// learner's words looks like, and they were written from the rubric rather than from model
// output. A failure means the model now reads one of these explanations differently from the
// way a person does — which is a finding, and the whole reason the suite exists. Editing the
// expectation to match the new output converts a signal into silence and leaves the learner
// as the next thing that detects the drift.
//
// The order to work in:
//
// 1. Read the failing explanation again and decide, as a human, what it really covers. If the
//    expectation was wrong about the *text*, fix the expectation and say so — that is
//    correcting an authoring mistake, not loosening an assertion.
// 2. Otherwise the prompt is what moved. The instructions and the per-concept prompt live in
//    `OnDeviceFeedbackService`; the rubric and the misconception catalogue it is handed come
//    from `content.json`. Sharpen the instruction the model stopped following, or the rubric
//    wording it started reading differently, and run the suite again.
// 3. Re-run before concluding anything. The model is non-deterministic, so one run is evidence
//    and two agreeing runs are a result.
//
// Fixtures encode a judgement, so a change to one is reviewed by a person the same way the
// authored content is.

/// Whether the gated half of this file runs.
///
/// The rule takes the environment as an argument rather than reading the process's own, so it
/// can be tested: the gate is the thing standing between an ineligible Mac and a red default
/// run, and a gate nobody tested is a gate nobody trusts.
enum PromptRegression {

    /// The variable that turns the real-inference suite on.
    static let environmentVariable = "XFORCE_PROMPT_REGRESSION"

    /// Whether this process was asked for the real-inference suite.
    static var isEnabled: Bool {
        isEnabled(in: ProcessInfo.processInfo.environment)
    }

    /// Set to anything meaningful turns the suite on. Absent, empty, whitespace and `0` leave
    /// it off — `0` because a variable exported as off is a way people expect to say no, and
    /// reading it as yes would be the worst possible direction for this particular mistake.
    static func isEnabled(in environment: [String: String]) -> Bool {
        guard let value = environment[environmentVariable]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            return false
        }

        return value.isEmpty == false && value != "0"
    }
}

// MARK: - The fixtures themselves, checked without a model

/// Runs in the default suite, on any Mac, with no inference.
///
/// The gated suite cannot run everywhere, so the part of it that can — that every fixture
/// points at content that ships, expects rubric numbers the concept actually has, and expects
/// misconceptions that belong to that concept — is asserted here instead. Without this, a
/// fixture could rot against the ontology for months and only be discovered by whoever next
/// had eligible hardware to hand.
@MainActor
struct PromptRegressionFixtureTests {

    // MARK: The gate

    @Test func theSuiteIsOffWhenTheVariableIsNotSet() {
        #expect(PromptRegression.isEnabled(in: [:]) == false)
        #expect(PromptRegression.isEnabled(in: ["SOMETHING_ELSE": "1"]) == false)
    }

    @Test(arguments: ["", " ", "0"])
    func theSuiteIsOffWhenTheVariableSaysNothingOrSaysNo(value: String) {
        let environment = [PromptRegression.environmentVariable: value]

        #expect(PromptRegression.isEnabled(in: environment) == false)
    }

    @Test(arguments: ["1", "yes", "true"])
    func theSuiteIsOnWhenTheVariableCarriesAValue(value: String) {
        let environment = [PromptRegression.environmentVariable: value]

        #expect(PromptRegression.isEnabled(in: environment))
    }

    // MARK: The fixture set

    /// Five or six is the range the ticket authored the set against: enough to span the three
    /// cases below without spending more inference time per run than anyone will sit through.
    @Test func theSetHoldsFiveOrSixFixturesWithDistinctIdentifiers() {
        let fixtures = PromptRegressionFixture.all

        #expect((5...6).contains(fixtures.count), "the set holds \(fixtures.count) fixtures")
        #expect(Set(fixtures.map(\.id)).count == fixtures.count)
    }

    @Test func everyFixtureNamesAnAuthoredConceptAndOneOfItsSnippets() throws {
        let content = ContentService()

        for fixture in PromptRegressionFixture.all {
            #expect(content.concept(withID: fixture.conceptID) != nil, "\(fixture.id)")

            let snippet = try #require(content.snippet(withID: fixture.snippetID), "\(fixture.id)")
            #expect(snippet.conceptID == fixture.conceptID, "\(fixture.id) crosses concepts")
            #expect(fixture.explanation.isEmpty == false, "\(fixture.id) has no explanation")
        }
    }

    /// The assertion that makes the gated suite's set comparison mean anything: an expected
    /// number the rubric does not have could never be reported, so the fixture would fail
    /// forever and say nothing about the model.
    @Test func everyExpectedRubricPointIsOneTheConceptActuallyHas() throws {
        let content = ContentService()

        for fixture in PromptRegressionFixture.all {
            let concept = try #require(content.concept(withID: fixture.conceptID))
            let numbers = Set(concept.rubric.map(\.number))

            #expect(
                fixture.expectedCoveredRubricPoints.isSubset(of: numbers),
                "\(fixture.id) expects \(fixture.expectedCoveredRubricPoints.sorted()) of \(numbers.sorted())"
            )
        }
    }

    /// The model's answer is filtered to the current concept's own misconceptions before a
    /// learner sees it, so a fixture expecting one from another concept would be expecting
    /// something the app discards.
    @Test func everyExpectedMisconceptionBelongsToTheFixturesConcept() throws {
        let content = ContentService()

        for fixture in PromptRegressionFixture.all {
            let concept = try #require(content.concept(withID: fixture.conceptID))
            let authored = Set(concept.misconceptions.map(\.id))

            for misconception in fixture.expectedMisconceptions {
                #expect(
                    authored.contains(misconception.rawValue),
                    "\(fixture.id) expects \(misconception.rawValue), which \(concept.id) does not author"
                )
            }
        }
    }

    // MARK: The three cases the set has to span

    /// Derived from the expectations rather than from a label on each fixture. A fixture
    /// labelled "complete" that expects three of five points would satisfy a label check and
    /// nothing else; this cannot be satisfied by naming.
    @Test func theSetSpansACompleteExplanationAPartialOneAndOneCarryingAMisconception() throws {
        let content = ContentService()

        var complete: [String] = []
        var partial: [String] = []
        var carryingAMisconception: [String] = []

        for fixture in PromptRegressionFixture.all {
            let concept = try #require(content.concept(withID: fixture.conceptID))
            let rubric = Set(concept.rubric.map(\.number))
            let covered = fixture.expectedCoveredRubricPoints

            if fixture.expectedMisconceptions.isEmpty == false {
                carryingAMisconception.append(fixture.id)
            } else if covered == rubric {
                complete.append(fixture.id)
            } else if covered.isEmpty == false {
                partial.append(fixture.id)
            }
        }

        #expect(complete.isEmpty == false, "no fixture covers its whole rubric")
        #expect(partial.isEmpty == false, "no fixture is correct but partial")
        #expect(carryingAMisconception.isEmpty == false, "no fixture carries a misconception")
    }
}

// MARK: - The real model

/// Seam three: real inference against the shipped prompt, gated behind
/// `XFORCE_PROMPT_REGRESSION`.
///
/// Serialised because every test here spends the same on-device model, and running six
/// inferences at once buys nothing but contention and a slower answer.
@Suite(.enabled(if: PromptRegression.isEnabled), .serialized)
struct PromptRegressionTests {

    /// Asserted rather than skipped. The suite was asked for explicitly, so a Mac that cannot
    /// run the model is a failure to report, not a condition to quietly pass over — the whole
    /// value of this suite is that it never claims to have checked something it did not check.
    @Test func theModelIsThereToRegressAgainst() {
        let service = OnDeviceFeedbackService()

        #expect(
            service.availability.isAvailable,
            """
            \(PromptRegression.environmentVariable) was set, but the on-device model is \
            unavailable (\(service.availability)). Run this suite on a Mac eligible for Apple \
            Intelligence, with it enabled and the model downloaded.
            """
        )
    }

    /// The regression itself: one fixture, one inference, two set comparisons.
    ///
    /// A failure here means the model now reads a learner's words differently from the way a
    /// person does. Read the guidance at the top of this file before touching a fixture.
    @Test(arguments: PromptRegressionFixture.all)
    func theModelJudgesTheExplanationTheWayAPersonDoes(fixture: PromptRegressionFixture) async throws {
        let service = OnDeviceFeedbackService()
        try #require(
            service.availability.isAvailable,
            "the on-device model is unavailable (\(service.availability))"
        )

        let (concept, snippet) = try await authoredContent(for: fixture)

        let feedback = try await service.feedback(
            concept: concept,
            snippet: snippet,
            explanation: fixture.explanation
        )

        #expect(
            Set(feedback.coveredRubricPoints) == fixture.expectedCoveredRubricPoints,
            """
            \(fixture.id): the model read rubric points \
            \(feedback.coveredRubricPoints.sorted()) as covered, a person reads \
            \(fixture.expectedCoveredRubricPoints.sorted()). Re-examine the prompt, not this \
            expectation.
            """
        )

        #expect(
            Set(feedback.misconceptions) == fixture.expectedMisconceptions,
            """
            \(fixture.id): the model detected \
            \(feedback.misconceptions.map(\.rawValue).sorted()), a person detects \
            \(fixture.expectedMisconceptions.map(\.rawValue).sorted()). Re-examine the prompt, \
            not this expectation.
            """
        )

        // The only thing asserted about the question is that there is one. Its wording is
        // meant to vary, and an assertion over it would be the string matching this suite
        // exists to avoid — but a session that comes back with no question at all is a
        // broken half of the loop rather than a matter of phrasing.
        #expect(feedback.socraticQuestion.isEmpty == false, "\(fixture.id) came back with no question")
    }
}

/// The concept and snippet a fixture names, read from the content that actually ships.
///
/// `ContentService` is `@MainActor`; the fixtures and the service under test are not. Both
/// returned values are `Sendable` value types, so hopping on for the lookup and back off for
/// the inference costs nothing and keeps generation off the main actor where it belongs.
@MainActor
private func authoredContent(for fixture: PromptRegressionFixture) throws -> (Concept, Snippet) {
    let content = ContentService()

    let concept = try #require(content.concept(withID: fixture.conceptID), "\(fixture.id)")
    let snippet = try #require(content.snippet(withID: fixture.snippetID), "\(fixture.id)")

    return (concept, snippet)
}
