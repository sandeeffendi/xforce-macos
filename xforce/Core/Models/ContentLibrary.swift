//
//  ContentLibrary.swift
//  xforce
//

import Foundation

/// The whole of the bundled ontology: the root of the content JSON.
///
/// Concepts and snippets are decoded together because validation is a statement about both
/// at once — a snippet is only meaningful if the concept it names exists.
nonisolated struct ContentLibrary: Hashable, Codable, Sendable {
    let concepts: [Concept]
    let snippets: [Snippet]
}
