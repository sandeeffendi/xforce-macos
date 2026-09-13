//
//  ContentService.swift
//  xforce
//

import Foundation
import Observation

/// Why the bundled content could not be used.
///
/// Equatable and specific rather than a single opaque failure, so a test can assert that a
/// particular rule rejected a particular snippet rather than merely that something went wrong.
nonisolated enum ContentError: Error, Equatable {

    /// The content file is missing from the bundle or could not be read.
    case unreadable(String)

    /// The content file is present but is not the shape the app expects.
    case malformed(String)

    /// The content carries no concepts, or no snippets, so there is nothing to practise.
    case empty

    /// A snippet names a concept that does not exist in the ontology.
    case unknownConcept(snippetID: String, conceptID: String)

    /// A snippet ships without the ground truth the loop depends on.
    case emptyExpectedOutput(snippetID: String)

    var message: String {
        switch self {
        case .unreadable(let detail):
            "The bundled content could not be read: \(detail)"
        case .malformed(let detail):
            "The bundled content is not in the expected format: \(detail)"
        case .empty:
            "The bundled content contains no snippets to practise."
        case .unknownConcept(let snippetID, let conceptID):
            "Snippet \(snippetID) refers to an unknown concept \(conceptID)."
        case .emptyExpectedOutput(let snippetID):
            "Snippet \(snippetID) ships without an expected output."
        }
    }
}

/// Loads the read-only ontology and snippets from the app bundle and validates them at launch.
///
/// Created once in `XforceApp` and read through `@Environment`, the way `Router` already is.
/// Nothing here is written at runtime: user data lives elsewhere.
///
/// Initialisation does not throw. A failure is recorded in ``failure`` and surfaced by the
/// screen as a failed state, so a corrupt bundle degrades to an explanation rather than to a
/// crash or to an empty screen with no reason given.
@MainActor
@Observable
final class ContentService {

    private(set) var concepts: [Concept] = []
    private(set) var snippets: [Snippet] = []

    /// The rule that rejected the content, or `nil` when the content is usable.
    private(set) var failure: ContentError?

    /// Loads and validates the content shipped in `bundle`.
    init(bundle: Bundle = .main) {
        do {
            adopt(try Self.validated(Self.decodeLibrary(from: bundle)))
        } catch let error as ContentError {
            failure = error
        } catch {
            failure = .unreadable(String(describing: error))
        }
    }

    /// Validates an in-memory library. Used by tests to exercise one rule at a time.
    init(library: ContentLibrary) {
        do {
            adopt(try Self.validated(library))
        } catch let error as ContentError {
            failure = error
        } catch {
            failure = .malformed(String(describing: error))
        }
    }

    /// The snippet the learner is shown when the practice screen opens.
    ///
    /// Scheduling chooses this in a later slice; until then the loop always starts at the
    /// beginning of the authored order.
    var firstSnippet: Snippet? { snippets.first }

    func concept(withID id: String) -> Concept? {
        concepts.first { $0.id == id }
    }

    func snippets(forConceptID id: String) -> [Snippet] {
        snippets.filter { $0.conceptID == id }
    }

    private func adopt(_ library: ContentLibrary) {
        concepts = library.concepts
        snippets = library.snippets
    }

    private static func decodeLibrary(from bundle: Bundle) throws -> ContentLibrary {
        guard let url = bundle.url(forResource: Self.resourceName, withExtension: "json") else {
            throw ContentError.unreadable("\(Self.resourceName).json is not in the bundle")
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ContentError.unreadable(error.localizedDescription)
        }

        do {
            return try JSONDecoder().decode(ContentLibrary.self, from: data)
        } catch {
            throw ContentError.malformed(String(describing: error))
        }
    }

    /// The rules the app cannot run without. The wider authoring contract — three snippets
    /// per concept, expected output free of stray whitespace — is asserted by the content
    /// integrity suite, which fails the build rather than the launch.
    private static func validated(_ library: ContentLibrary) throws -> ContentLibrary {
        guard library.concepts.isEmpty == false, library.snippets.isEmpty == false else {
            throw ContentError.empty
        }

        let conceptIDs = Set(library.concepts.map(\.id))

        for snippet in library.snippets {
            guard conceptIDs.contains(snippet.conceptID) else {
                throw ContentError.unknownConcept(snippetID: snippet.id, conceptID: snippet.conceptID)
            }

            guard snippet.expectedOutput.isEmpty == false else {
                throw ContentError.emptyExpectedOutput(snippetID: snippet.id)
            }
        }

        return library
    }

    private static let resourceName = "content"
}
