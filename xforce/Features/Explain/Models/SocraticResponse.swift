//
//  SocraticResponse.swift
//  xforce
//

import Foundation

/// What the learner did with the question they were asked.
///
/// Two cases rather than a `String?`, because "skipped" and "answered with nothing" are
/// genuinely different things to have recorded about someone's thinking, and a nil string
/// cannot tell them apart. The record is evidence, so the distinction has to survive into it.
///
/// This is deliberately **not** an input to anything: no feedback reads it and the outcome
/// comes from the output comparison. Recording it without feeding it back is what keeps the
/// data uncontaminated.
nonisolated enum SocraticResponse: Hashable, Sendable {

    /// The learner wrote something. The text may be empty — they pressed answer with an
    /// empty field, which is still not the same as declining to answer.
    case answered(String)

    /// The learner had nothing to add and said so.
    case skipped
}
