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
    case explain
    case graph
}
