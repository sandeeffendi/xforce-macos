//
//  MisconceptionID.swift
//  xforce
//

import Foundation
import FoundationModels

/// The closed set of misconceptions the model is allowed to report.
///
/// This is the one place guided generation genuinely earns its keep. Detecting a wrong belief
/// is the single thing in the feedback panel only a model can do, and constraining the output
/// to a `@Generable` enum makes it *physically impossible* for the model to invent a label
/// outside the ontology — not unlikely, impossible. Everything else the panel shows is either
/// computed in Swift or read straight from authored data.
///
/// **Hand-written and committed**, deliberately. Generating it from `content.json` during the
/// build would need a script phase writing into the source tree, which fights the project's
/// file-system-synchronised groups and its rule against hand-editing the project file. A test
/// buys the same guarantee with no build machinery: the content integrity suite asserts that
/// this enum and the ontology match **in both directions**, so an id authored with no case
/// here, or a case here the ontology no longer authors, fails the build rather than the
/// learner.
///
/// The raw value is the authored `Misconception.id` it names. That is the whole link between
/// what the model may say and what the panel can show: a reported case is looked up by raw
/// value in the current concept's own misconception list, and anything that does not belong to
/// that concept is discarded before it reaches the learner.
///
/// Adding a concept to the ontology means adding its misconceptions here. The test will say so.
@Generable
nonisolated enum MisconceptionID: String, CaseIterable, Hashable, Sendable {

    // MARK: Optionals

    case optionalIsTheSameAsTheValue = "optional-is-the-same-as-the-value"
    case printingShowsTheValue = "printing-shows-the-value"
    case nilCoalescingUnwrapsPermanently = "nil-coalescing-unwraps-permanently"
    case nilIsZeroOrEmpty = "nil-is-zero-or-empty"
}
