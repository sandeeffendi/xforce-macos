//
//  RouteBuilder.swift
//  xforce
//

import SwiftUI

/// The single place an `AppRoute` becomes a `View`.
///
/// This is the one sanctioned exception to the rule that `Core` must not reference a
/// feature. Keeping the mapping in exactly one place is what lets the whole app navigate
/// by value, with a single `.navigationDestination(for: AppRoute.self)` in `AppRootView`.
enum RouteBuilder {

    @MainActor
    @ViewBuilder
    static func view(for route: AppRoute) -> some View {
        switch route {
        case .explain: ExplainScreen()
        case .session(let conceptID): ExplainScreen(conceptID: conceptID)
        case .graph: GraphScreen()
        }
    }
}
