//
//  Snippet.swift
//  xforce
//

import Foundation

/// A Swift snippet the learner predicts the console output of.
///
/// `expectedOutput` was computed once while the snippet was authored and ships as data.
/// **The app never executes Swift**, so this is the only ground truth the loop has, which is
/// why the authoring contract around it is asserted by its own test suite.
nonisolated struct Snippet: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let conceptID: String

    /// The source shown to the learner, rendered as code.
    let code: String

    /// Exactly what the snippet prints, verbatim.
    let expectedOutput: String
}
