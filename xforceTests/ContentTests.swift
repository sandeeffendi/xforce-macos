//
//  ContentTests.swift
//  xforceTests
//

import Foundation
import Testing
@testable import xforce

/// Seam two: the authoring contract for the bundled assets.
///
/// This is not a behaviour test. It validates data that ships with the app, because an
/// authoring slip that escapes this check would fail every learner on that snippet forever.
@MainActor
struct ContentIntegrityTests {

    @Test func theBundledContentLoadsWithoutAValidationFailure() {
        let service = ContentService()

        #expect(service.failure == nil)
    }

    @Test func atLeastOneConceptShips() {
        let service = ContentService()

        #expect(service.concepts.isEmpty == false)
    }

    @Test func everyConceptShipsAtLeastThreeSnippets() {
        let service = ContentService()

        for concept in service.concepts {
            let snippets = service.snippets.filter { $0.conceptID == concept.id }
            #expect(snippets.count >= 3, "\(concept.id) ships \(snippets.count) snippets")
        }
    }

    @Test func everySnippetResolvesToAConceptThatExists() {
        let service = ContentService()
        let conceptIDs = Set(service.concepts.map(\.id))

        for snippet in service.snippets {
            #expect(conceptIDs.contains(snippet.conceptID), "\(snippet.id) points at \(snippet.conceptID)")
        }
    }

    @Test func everySnippetCarriesCodeAndANonEmptyExpectedOutput() {
        let service = ContentService()

        for snippet in service.snippets {
            #expect(snippet.code.isEmpty == false, "\(snippet.id) has no code")
            #expect(snippet.expectedOutput.isEmpty == false, "\(snippet.id) has no expected output")
        }
    }

    @Test func noExpectedOutputCarriesStrayLeadingOrTrailingWhitespace() {
        let service = ContentService()

        for snippet in service.snippets {
            let trimmed = snippet.expectedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(snippet.expectedOutput == trimmed, "\(snippet.id) is padded with whitespace")

            for line in snippet.expectedOutput.components(separatedBy: "\n") {
                #expect(line == trimmedTrailing(line), "\(snippet.id) has a line with trailing whitespace")
            }
        }
    }

    @Test func everyConceptCarriesASummaryARubricAndCuratedMisconceptions() {
        let service = ContentService()

        for concept in service.concepts {
            #expect(concept.name.isEmpty == false)
            #expect(concept.summary.isEmpty == false)
            #expect(concept.rubric.isEmpty == false, "\(concept.id) has no rubric")
            #expect(concept.misconceptions.isEmpty == false, "\(concept.id) has no misconceptions")
        }
    }

    @Test func rubricPointsAreNumberedFromOneWithoutGaps() {
        let service = ContentService()

        for concept in service.concepts {
            let numbers = concept.rubric.map(\.number)
            #expect(numbers == Array(1...concept.rubric.count), "\(concept.id) has a broken rubric numbering")
        }
    }

    private func trimmedTrailing(_ line: String) -> String {
        var line = line
        while let last = line.last, last.isWhitespace {
            line.removeLast()
        }
        return line
    }
}

/// The service validates at launch, so the rules it enforces need to be shown to actually
/// reject something — otherwise the integrity suite above could pass vacuously.
@MainActor
struct ContentServiceValidationTests {

    @Test func wellFormedContentIsAccepted() {
        let service = ContentService(library: .fixture())

        #expect(service.failure == nil)
        #expect(service.concepts.count == 1)
        #expect(service.snippets.count == 1)
    }

    @Test func contentWithNoSnippetsIsRejected() {
        let library = ContentLibrary(concepts: ContentLibrary.fixture().concepts, snippets: [])

        let service = ContentService(library: library)

        #expect(service.failure == .empty)
    }

    @Test func aSnippetPointingAtAnUnknownConceptIsRejected() {
        let library = ContentLibrary.fixture(conceptID: "optionals", snippetConceptID: "closures")

        let service = ContentService(library: library)

        #expect(service.failure == .unknownConcept(snippetID: "fixture-snippet", conceptID: "closures"))
    }

    @Test func anEmptyExpectedOutputIsRejected() {
        let library = ContentLibrary.fixture(expectedOutput: "")

        let service = ContentService(library: library)

        #expect(service.failure == .emptyExpectedOutput(snippetID: "fixture-snippet"))
    }

    @Test func rejectedContentExposesNoConceptsOrSnippets() {
        let service = ContentService(library: ContentLibrary(concepts: [], snippets: []))

        #expect(service.concepts.isEmpty)
        #expect(service.snippets.isEmpty)
    }
}

extension ContentLibrary {

    /// A minimal library that satisfies the service's validation rules, so a test can change
    /// exactly one thing and assert on the consequence.
    static func fixture(
        conceptID: String = "optionals",
        snippetConceptID: String? = nil,
        code: String = "print(1)",
        expectedOutput: String = "1"
    ) -> ContentLibrary {
        ContentLibrary(
            concepts: [
                Concept(
                    id: conceptID,
                    name: "Optionals",
                    summary: "A value that may be absent.",
                    rubric: [RubricPoint(number: 1, text: "An optional either holds a value or holds nil.")],
                    misconceptions: [
                        Misconception(
                            id: "printing-shows-the-value",
                            name: "Printing an optional prints the value it holds",
                            correction: "Printing an optional shows the Optional(...) wrapper."
                        )
                    ]
                )
            ],
            snippets: [
                Snippet(
                    id: "fixture-snippet",
                    conceptID: snippetConceptID ?? conceptID,
                    code: code,
                    expectedOutput: expectedOutput
                )
            ]
        )
    }
}
