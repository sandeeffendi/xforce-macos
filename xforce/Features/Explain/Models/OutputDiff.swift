//
//  OutputDiff.swift
//  xforce
//

import Foundation

/// A line-by-line comparison of what the learner predicted against what the snippet prints.
///
/// Comparison normalises leading and trailing whitespace per line and drops trailing blank
/// lines. It is **case-sensitive** and **preserves interior spacing**, deliberately: `5` must
/// not be accepted where `Optional(5)` was printed, and `True` must not be accepted where
/// `true` was.
///
/// Looser normalisation was rejected. Collapsing interior runs of spaces would hide meaningful
/// spacing produced by multi-argument printing, and a case-insensitive comparison would stop
/// the app distinguishing `Optional` from `optional`. The defence against an unfairly failed
/// prediction is tighter snippet authoring and a clearly labelled console-output field, not a
/// more forgiving comparison.
nonisolated struct OutputDiff: Hashable, Sendable {

    /// One position in the comparison. A `nil` side means that side has no line there at all.
    nonisolated struct Line: Identifiable, Hashable, Sendable {
        /// One-based, so it reads the way a console does.
        let number: Int
        let predicted: String?
        let expected: String?

        var id: Int { number }

        var matches: Bool { predicted == expected }
    }

    let lines: [Line]

    /// True only when every line lines up. An empty comparison is never correct, so a
    /// prediction that normalises away to nothing cannot pass.
    var isCorrect: Bool {
        lines.isEmpty == false && lines.allSatisfy(\.matches)
    }

    /// Compares a raw prediction against the snippet's authored expected output.
    static func comparing(prediction: String, expected: String) -> OutputDiff {
        let predicted = normalised(prediction)
        let truth = normalised(expected)

        let lines = (0..<max(predicted.count, truth.count)).map { index in
            Line(
                number: index + 1,
                predicted: predicted.indices.contains(index) ? predicted[index] : nil,
                expected: truth.indices.contains(index) ? truth[index] : nil
            )
        }

        return OutputDiff(lines: lines)
    }

    /// Splits into lines, trims each line's leading and trailing whitespace, and drops
    /// trailing blank lines. Interior blank lines survive, because a snippet that prints one
    /// genuinely printed it.
    private static func normalised(_ text: String) -> [String] {
        var lines = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        while lines.last?.isEmpty == true {
            lines.removeLast()
        }

        return lines
    }
}
