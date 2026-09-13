//
//  ConceptProgress.swift
//  xforce
//

import Foundation
import SwiftData

/// Where one concept sits in the learner's five-box Leitner schedule.
///
/// Exactly one record exists per concept — `#Unique` states that in the store rather than
/// leaving it to the code that writes it — and it is opened the first time a session on that
/// concept is committed. A concept with no record has never been attempted, which is a
/// different thing from a concept the learner is struggling with.
///
/// The transitions live here rather than in the service that writes them, so the clamping at
/// both ends cannot be bypassed by writing the box directly. Nothing about the transition is
/// generated: a model can move an outcome between mastered and fragile, never to failed.
///
/// Due dates are recorded even though nothing re-engages the learner on them yet, so that
/// adding notifications later reads the schedule rather than inventing it.
@Model
final class ConceptProgress {

    #Unique<ConceptProgress>([\.conceptID])

    /// The concept this record tracks, referencing the read-only ontology by id.
    private(set) var conceptID: String

    /// Which of the five boxes the concept currently sits in.
    private(set) var box: Int

    /// When the learner last committed a session on this concept.
    private(set) var lastReviewedAt: Date

    /// When the concept next falls due, from the interval its box carries.
    private(set) var dueAt: Date

    /// Opens a record on a concept the learner has just met, in the first box. The outcome of
    /// the session that created it is applied on top by ``record(_:at:)``.
    init(conceptID: String, at date: Date = .now) {
        self.conceptID = conceptID
        self.box = Self.firstBox
        self.lastReviewedAt = date
        self.dueAt = Self.dueDate(forBox: Self.firstBox, reviewedAt: date)
    }

    /// How well the concept is understood, computed from the box every time it is read.
    ///
    /// Derived rather than stored: a second value written alongside the box is a second value
    /// that can drift out of step with it.
    var masteryLevel: MasteryLevel { MasteryLevel(box: box) }

    /// Applies one committed session, moving the box and recomputing when the concept is due.
    ///
    /// - `mastered`: the box goes up one and stops at five.
    /// - `fragile`: the box does not move. A correct prediction carrying a misconception is
    ///   neither progress nor a relapse.
    /// - `failed`: the box goes back to one.
    func record(_ outcome: SessionOutcome, at date: Date) {
        box = Self.nextBox(after: outcome, from: box)
        lastReviewedAt = date
        dueAt = Self.dueDate(forBox: box, reviewedAt: date)
    }

    /// The first box, and the one a failed session sends a concept back to.
    static let firstBox = 1

    /// The last box. A mastered session on a concept already here leaves it here.
    static let lastBox = 5

    /// What each box waits, in days, from box one through box five.
    private static let intervalsInDays = [1, 3, 7, 16, 35]

    private static func intervalInDays(forBox box: Int) -> Int {
        intervalsInDays[min(max(box, firstBox), lastBox) - 1]
    }

    private static func nextBox(after outcome: SessionOutcome, from box: Int) -> Int {
        switch outcome {
        case .mastered: min(box + 1, lastBox)
        case .fragile: box
        case .failed: firstBox
        }
    }

    /// Counted in calendar days rather than in a fixed span of seconds, so an interval that
    /// crosses a daylight-saving change still lands on the day it names.
    private static func dueDate(forBox box: Int, reviewedAt date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: intervalInDays(forBox: box), to: date) ?? date
    }
}

/// How well the learner understands a concept, derived from its Leitner box.
///
/// `untouched` is a level of its own rather than the bottom of the scale: "not yet attempted"
/// and "attempted and struggling" are different things, and the graph that colours by this
/// would tell the learner something untrue about their own progress if it treated them alike.
nonisolated enum MasteryLevel: String, CaseIterable, Sendable {
    case untouched
    case weak
    case developing
    case strong

    /// - Parameter box: the concept's Leitner box, or `nil` when it has no progress record.
    init(box: Int?) {
        switch box {
        case .none:
            self = .untouched
        case .some(let box) where box <= ConceptProgress.firstBox:
            self = .weak
        case .some(let box) where box <= 3:
            self = .developing
        default:
            self = .strong
        }
    }

    /// What the level is called where it is shown. Words, not only a colour: the graph pairs
    /// every node's colour with this in its legend and in the node's accessibility label, so
    /// the meaning survives a screen reader and a colour-blind reader alike.
    var title: String {
        switch self {
        case .untouched: "Not yet attempted"
        case .weak: "Struggling"
        case .developing: "Developing"
        case .strong: "Strong"
        }
    }
}
