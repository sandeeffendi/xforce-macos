//
//  AppRoute.swift
//  xforce
//

import Foundation

/// A destination that can be pushed onto the detail navigation stack.
///
/// A route must describe its destination completely as a value — carry identifiers, never
/// object references. That is what allows navigation to be driven from outside the view
/// hierarchy later (deep links, state restoration, menu commands) without touching screens.
nonisolated enum AppRoute: Hashable {

    /// The practice loop on whatever the learner should work on next. The root of the
    /// explain section, which is why it carries nothing: what comes next is the loop's own
    /// decision, made from the content and the store.
    case explain

    /// The practice loop on one named concept — the deliberate revisit the graph offers.
    ///
    /// A separate case rather than a payload on ``explain`` because the two are different
    /// intents: one asks the app what to practise, the other says what to practise. Carrying
    /// the id rather than the concept is what lets this be pushed from anywhere and, later,
    /// arrive from a URL.
    case session(conceptID: String)

    case graph
}
