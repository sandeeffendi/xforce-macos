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

    /// Edge resolution and self-reference are asserted by `ContentGraphIntegrityTests` below,
    /// which owns the authored edges. The panel's "connect this" section reads the same two
    /// fields, so it is covered by the same guarantee rather than by a second copy of it.
    @Test func misconceptionIdsAreUniqueAcrossTheWholeOntology() {
        let service = ContentService()
        let ids = service.concepts.flatMap { $0.misconceptions.map(\.id) }

        #expect(Set(ids).count == ids.count, "two concepts share a misconception id")
    }

    /// The one guarantee that replaces a build script. The enum is hand-written and committed,
    /// so nothing keeps it in step with the ontology except this: an id authored into the
    /// content with no case, or a case with no id, fails the build rather than the learner.
    @Test func theMisconceptionEnumMatchesTheOntologyInBothDirections() {
        let service = ContentService()
        let authored = Set(service.concepts.flatMap { $0.misconceptions.map(\.id) })
        let generable = Set(MisconceptionID.allCases.map(\.rawValue))

        #expect(
            authored.subtracting(generable).isEmpty,
            "the ontology authors misconceptions the enum has no case for: \(authored.subtracting(generable).sorted())"
        )
        #expect(
            generable.subtracting(authored).isEmpty,
            "the enum carries cases the ontology no longer authors: \(generable.subtracting(authored).sorted())"
        )
        #expect(authored == generable)
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

/// The part of the authoring contract the graph depends on.
///
/// Positions and edges are authored by hand, so the slips they invite — two concepts drawn on
/// top of each other, an edge pointing at a concept that was renamed — are slips no compiler
/// catches. They fail the build here rather than reaching a learner as an unreadable map.
@MainActor
struct ContentGraphIntegrityTests {

    @Test func everyConceptCarriesAPositionInsideTheUnitSquare() {
        let service = ContentService()

        for concept in service.concepts {
            #expect(ConceptPosition.unitRange.contains(concept.position.x), "\(concept.id) sits outside on x")
            #expect(ConceptPosition.unitRange.contains(concept.position.y), "\(concept.id) sits outside on y")
        }
    }

    @Test func noTwoConceptsAreAuthoredOnTopOfEachOther() {
        let service = ContentService()

        let positions = Set(service.concepts.map(\.position))
        #expect(positions.count == service.concepts.count, "two concepts share a position")
    }

    @Test func everyPrerequisiteAndRelatedIDResolvesToAConceptThatShips() {
        let service = ContentService()
        let conceptIDs = Set(service.concepts.map(\.id))

        for concept in service.concepts {
            for neighbour in concept.prerequisites + concept.related {
                #expect(conceptIDs.contains(neighbour), "\(concept.id) points at unknown concept \(neighbour)")
            }
        }
    }

    @Test func noConceptNamesItselfAsAPrerequisiteOrAsRelated() {
        let service = ContentService()

        for concept in service.concepts {
            #expect(concept.prerequisites.contains(concept.id) == false, "\(concept.id) is its own prerequisite")
            #expect(concept.related.contains(concept.id) == false, "\(concept.id) is related to itself")
        }
    }

    /// The same authoring order snippet selection already leans on, now stated where it can be
    /// checked: no concept is authored before something it depends on.
    @Test func prerequisitesAreAuthoredBeforeTheConceptsThatNeedThem() {
        let service = ContentService()
        var seen: Set<String> = []

        for concept in service.concepts {
            for prerequisite in concept.prerequisites {
                #expect(seen.contains(prerequisite), "\(concept.id) needs \(prerequisite), authored after it")
            }
            seen.insert(concept.id)
        }
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
                    position: ConceptPosition(x: 0.5, y: 0.5),
                    prerequisites: [],
                    related: [],
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
