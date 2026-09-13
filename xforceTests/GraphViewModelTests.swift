//
//  GraphViewModelTests.swift
//  xforceTests
//

import Foundation
import SwiftData
import Testing
@testable import xforce

/// Seam four: the map of the learner's own understanding.
///
/// The graph is the one screen that must work on any Mac, so every suite here builds the view
/// model from the content and the store alone — no feedback service is involved anywhere, and
/// that absence is the point rather than an omission.
@MainActor
struct ConceptGraphNodeTests {

    @Test func everyConceptIsDrawnIncludingTheOnesNeverAttempted() throws {
        let viewModel = try graphViewModel(
            concepts: [
                .graphFixture(id: "variables", position: ConceptPosition(x: 0.2, y: 0.2)),
                .graphFixture(id: "optionals", position: ConceptPosition(x: 0.5, y: 0.5)),
                .graphFixture(id: "closures", position: ConceptPosition(x: 0.8, y: 0.8)),
            ]
        )

        viewModel.load()

        #expect(viewModel.state == .loaded)
        #expect(viewModel.nodes.map(\.id) == ["variables", "optionals", "closures"])
        #expect(viewModel.nodes.allSatisfy { $0.mastery == .untouched })
    }

    @Test func aNodeSitsWhereTheContentSaysItSits() throws {
        let viewModel = try graphViewModel(
            concepts: [.graphFixture(id: "optionals", position: ConceptPosition(x: 0.25, y: 0.75))]
        )

        viewModel.load()

        #expect(viewModel.nodes.first?.position == ConceptPosition(x: 0.25, y: 0.75))
    }

    /// The whole reason the layout is authored rather than simulated: the map has to be the
    /// same map every time the learner opens it.
    @Test func nodesAreInTheSamePlaceEveryTimeTheGraphIsOpened() throws {
        let concepts: [Concept] = [
            .graphFixture(id: "variables", position: ConceptPosition(x: 0.2, y: 0.2)),
            .graphFixture(id: "optionals", position: ConceptPosition(x: 0.5, y: 0.5), prerequisites: ["variables"]),
            .graphFixture(id: "closures", position: ConceptPosition(x: 0.8, y: 0.3), related: ["optionals"]),
        ]
        let content = ContentService(library: .graphFixture(concepts: concepts))
        let scheduling = SchedulingService.inMemory()

        let first = GraphViewModel(content: content, scheduling: scheduling)
        first.load()
        let second = GraphViewModel(content: content, scheduling: scheduling)
        second.load()

        #expect(first.nodes == second.nodes)
        #expect(first.edges == second.edges)
    }

    /// Reloading the same view model must not shuffle or duplicate anything either: the screen
    /// runs `load()` on every appearance.
    @Test func reloadingLeavesTheSameNodesAndEdges() throws {
        let viewModel = try graphViewModel(
            concepts: [
                .graphFixture(id: "variables", position: ConceptPosition(x: 0.2, y: 0.2)),
                .graphFixture(id: "optionals", position: ConceptPosition(x: 0.5, y: 0.5), prerequisites: ["variables"]),
            ]
        )
        viewModel.load()
        let nodes = viewModel.nodes
        let edges = viewModel.edges

        viewModel.load()

        #expect(viewModel.nodes == nodes)
        #expect(viewModel.edges == edges)
    }

    @Test func brokenContentLeavesTheScreenWithAReasonRatherThanAnEmptyCanvas() {
        let content = ContentService(library: ContentLibrary(concepts: [], snippets: []))

        let viewModel = GraphViewModel(content: content, scheduling: .inMemory())
        viewModel.load()

        #expect(viewModel.state == .failed(ContentError.empty.message))
        #expect(viewModel.nodes.isEmpty)
    }
}

/// The mapping from what the store holds to the colour a node is drawn in.
@MainActor
struct ConceptGraphMasteryTests {

    /// "Not yet attempted" and "attempted and struggling" are different things. A concept with
    /// no progress record must never be coloured as a weak one.
    @Test func aConceptWithNoProgressRecordIsUntouchedRatherThanWeak() throws {
        let viewModel = try graphViewModel(
            concepts: [.graphFixture(id: "optionals", position: ConceptPosition(x: 0.5, y: 0.5))]
        )

        viewModel.load()

        #expect(viewModel.nodes.first?.mastery == .untouched)
        #expect(viewModel.nodes.first?.mastery != .weak)
    }

    @Test(arguments: [
        (1, MasteryLevel.weak),
        (2, MasteryLevel.developing),
        (3, MasteryLevel.developing),
        (4, MasteryLevel.strong),
        (5, MasteryLevel.strong),
    ])
    func everyBoxMapsToTheMasteryLevelItColoursBy(box: Int, level: MasteryLevel) throws {
        let viewModel = try graphViewModel(
            concepts: [.graphFixture(id: "optionals", position: ConceptPosition(x: 0.5, y: 0.5))],
            boxes: ["optionals": box]
        )

        viewModel.load()

        #expect(viewModel.nodes.first?.mastery == level)
    }

    @Test func eachConceptIsColouredFromItsOwnProgress() throws {
        let viewModel = try graphViewModel(
            concepts: [
                .graphFixture(id: "variables", position: ConceptPosition(x: 0.2, y: 0.2)),
                .graphFixture(id: "optionals", position: ConceptPosition(x: 0.5, y: 0.5)),
                .graphFixture(id: "closures", position: ConceptPosition(x: 0.8, y: 0.8)),
            ],
            boxes: ["variables": 5, "optionals": 1]
        )

        viewModel.load()

        #expect(viewModel.nodes.map(\.mastery) == [.strong, .weak, .untouched])
    }

    /// Every level has to be reachable, otherwise a palette could distinguish four colours
    /// that the graph never actually draws.
    @Test func allFourLevelsCanAppearOnTheSameGraph() throws {
        let viewModel = try graphViewModel(
            concepts: [
                .graphFixture(id: "variables", position: ConceptPosition(x: 0.2, y: 0.2)),
                .graphFixture(id: "optionals", position: ConceptPosition(x: 0.4, y: 0.4)),
                .graphFixture(id: "closures", position: ConceptPosition(x: 0.6, y: 0.6)),
                .graphFixture(id: "protocols", position: ConceptPosition(x: 0.8, y: 0.8)),
            ],
            boxes: ["variables": 1, "optionals": 3, "closures": 5]
        )

        viewModel.load()

        #expect(Set(viewModel.nodes.map(\.mastery)) == Set(MasteryLevel.allCases))
    }
}

/// Edges come from the ontology's own authored fields. No embeddings, no similarity.
@MainActor
struct ConceptGraphEdgeTests {

    @Test func aPrerequisiteBecomesAnEdgeFromWhatComesFirst() throws {
        let viewModel = try graphViewModel(
            concepts: [
                .graphFixture(id: "variables", position: ConceptPosition(x: 0.2, y: 0.2)),
                .graphFixture(id: "optionals", position: ConceptPosition(x: 0.5, y: 0.5), prerequisites: ["variables"]),
            ]
        )

        viewModel.load()

        #expect(viewModel.edges == [ConceptEdge(from: "variables", to: "optionals", kind: .prerequisite)])
    }

    @Test func aRelatedConceptBecomesAnEdgeOfItsOwnKind() throws {
        let viewModel = try graphViewModel(
            concepts: [
                .graphFixture(id: "optionals", position: ConceptPosition(x: 0.2, y: 0.2), related: ["closures"]),
                .graphFixture(id: "closures", position: ConceptPosition(x: 0.5, y: 0.5)),
            ]
        )

        viewModel.load()

        #expect(viewModel.edges == [ConceptEdge(from: "optionals", to: "closures", kind: .related)])
    }

    @Test func aRelationshipAuthoredOnBothSidesIsDrawnOnce() throws {
        let viewModel = try graphViewModel(
            concepts: [
                .graphFixture(id: "optionals", position: ConceptPosition(x: 0.2, y: 0.2), related: ["closures"]),
                .graphFixture(id: "closures", position: ConceptPosition(x: 0.5, y: 0.5), related: ["optionals"]),
            ]
        )

        viewModel.load()

        #expect(viewModel.edges.count == 1)
    }

    /// A prerequisite says more than a bare relationship, so a pair authored as both is drawn
    /// as the prerequisite rather than as two lines between the same two nodes.
    @Test func aPairThatIsBothPrerequisiteAndRelatedIsDrawnAsThePrerequisite() throws {
        let viewModel = try graphViewModel(
            concepts: [
                .graphFixture(id: "variables", position: ConceptPosition(x: 0.2, y: 0.2), related: ["optionals"]),
                .graphFixture(id: "optionals", position: ConceptPosition(x: 0.5, y: 0.5), prerequisites: ["variables"]),
            ]
        )

        viewModel.load()

        #expect(viewModel.edges == [ConceptEdge(from: "variables", to: "optionals", kind: .prerequisite)])
    }

    @Test func anEdgeToAConceptThatDoesNotShipIsSkipped() throws {
        let viewModel = try graphViewModel(
            concepts: [
                .graphFixture(
                    id: "optionals",
                    position: ConceptPosition(x: 0.5, y: 0.5),
                    prerequisites: ["variables"],
                    related: ["generics"]
                )
            ]
        )

        viewModel.load()

        #expect(viewModel.edges.isEmpty)
    }

    @Test func aConceptThatNamesItselfDrawsNoEdge() throws {
        let viewModel = try graphViewModel(
            concepts: [
                .graphFixture(
                    id: "optionals",
                    position: ConceptPosition(x: 0.5, y: 0.5),
                    prerequisites: ["optionals"],
                    related: ["optionals"]
                )
            ]
        )

        viewModel.load()

        #expect(viewModel.edges.isEmpty)
    }

    @Test func edgesFollowTheAuthoredOrderOfTheConceptsTheyLeave() throws {
        let viewModel = try graphViewModel(
            concepts: [
                .graphFixture(id: "variables", position: ConceptPosition(x: 0.2, y: 0.2)),
                .graphFixture(id: "optionals", position: ConceptPosition(x: 0.5, y: 0.5), prerequisites: ["variables"]),
                .graphFixture(
                    id: "closures",
                    position: ConceptPosition(x: 0.8, y: 0.8),
                    prerequisites: ["optionals"],
                    related: ["variables"]
                ),
            ]
        )

        viewModel.load()

        #expect(
            viewModel.edges == [
                ConceptEdge(from: "variables", to: "optionals", kind: .prerequisite),
                ConceptEdge(from: "optionals", to: "closures", kind: .prerequisite),
                ConceptEdge(from: "closures", to: "variables", kind: .related),
            ]
        )
    }
}

// MARK: - Fixtures

@MainActor
private func graphViewModel(concepts: [Concept], boxes: [String: Int] = [:]) throws -> GraphViewModel {
    GraphViewModel(
        content: ContentService(library: .graphFixture(concepts: concepts)),
        scheduling: try schedulingService(boxes: boxes)
    )
}

/// A store holding one concept per requested box, reached the only way the app can reach it:
/// by committing sessions. A concept starts in box one and climbs one box per mastered
/// session, so box `n` is one fragile session followed by `n - 1` mastered ones.
@MainActor
private func schedulingService(boxes: [String: Int]) throws -> SchedulingService {
    let scheduling = SchedulingService.inMemory()

    for (conceptID, box) in boxes.sorted(by: { $0.key < $1.key }) {
        try scheduling.record(note(conceptID: conceptID, outcome: .fragile))

        for _ in 1..<max(box, 1) {
            try scheduling.record(note(conceptID: conceptID, outcome: .mastered))
        }
    }

    return scheduling
}

private func note(conceptID: String, outcome: SessionOutcome) -> Note {
    Note(
        conceptID: conceptID,
        snippetID: "\(conceptID)-snippet",
        prediction: "1",
        explanation: "Because it prints one.",
        outcome: outcome
    )
}

extension ContentLibrary {

    /// A library built around whatever concepts a graph test needs, with the single snippet
    /// the content service insists on so that validation passes and the graph is what is
    /// under test.
    static func graphFixture(concepts: [Concept]) -> ContentLibrary {
        ContentLibrary(
            concepts: concepts,
            snippets: [
                Snippet(
                    id: "\(concepts.first?.id ?? "fixture")-snippet",
                    conceptID: concepts.first?.id ?? "fixture",
                    code: "print(1)",
                    expectedOutput: "1"
                )
            ]
        )
    }
}

extension Concept {

    static func graphFixture(
        id: String,
        position: ConceptPosition,
        prerequisites: [String] = [],
        related: [String] = []
    ) -> Concept {
        Concept(
            id: id,
            name: id.capitalized,
            summary: "A short frame for \(id).",
            position: position,
            prerequisites: prerequisites,
            related: related,
            rubric: [RubricPoint(number: 1, text: "Something a complete explanation would say.")],
            misconceptions: [
                Misconception(id: "\(id)-misconception", name: "A wrong belief", correction: "What replaces it.")
            ]
        )
    }
}
