//
//  SessionOutcome.swift
//  xforce
//

import Foundation

/// What one committed session says about the learner's grip on the concept.
///
/// This is the only thing the Leitner schedule acts on, and it is derived rather than
/// generated. A wrong prediction is always ``failed`` and no model can ever cause that; the
/// most a model will ever do is move a correct prediction between ``mastered`` and ``fragile``
/// by reporting whether it detected a misconception alongside it.
///
/// It lives in `Core` rather than in the practice feature because the note that stores it and
/// the graph that colours concepts by it sit in different features, and features may not
/// import each other.
nonisolated enum SessionOutcome: String, Codable, CaseIterable, Sendable {

    /// Prediction correct, with no misconception detected.
    case mastered

    /// Prediction correct, but a misconception was detected alongside it.
    case fragile

    /// Prediction incorrect.
    case failed
}
