//
//  AppSection.swift
//  xforce
//

import Foundation

/// A top-level destination shown in the sidebar.
///
/// Separate from `AppRoute` on purpose: the sidebar is a closed, exhaustive set
/// (`CaseIterable` means it can never drift from what the app can show), while routes are
/// open-ended and include destinations that must never appear in the sidebar.
nonisolated enum AppSection: String, Hashable, CaseIterable, Identifiable {
    case explain
    case graph

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explain: "Explain"
        case .graph: "Graph View"
        }
    }

    var systemImage: String {
        switch self {
        case .explain: "text.bubble"
        case .graph: "point.3.connected.trianglepath.dotted"
        }
    }

    /// The route shown at the bottom of the detail stack when this section is selected.
    var rootRoute: AppRoute {
        switch self {
        case .explain: .explain
        case .graph: .graph
        }
    }
}
