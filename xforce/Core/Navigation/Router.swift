//
//  Router.swift
//  xforce
//

import Observation

/// Owns all navigation state for the main window.
///
/// Created once in `XforceApp` and read through `@Environment`. Screens never construct a
/// router, and never navigate by building a destination view — they express intent here.
@MainActor
@Observable
final class Router {

    /// The selected sidebar destination, which supplies the root of the detail stack.
    private(set) var section: AppSection

    /// Routes pushed on top of the current section's root.
    var path: [AppRoute]

    init(section: AppSection = .explain, path: [AppRoute] = []) {
        self.section = section
        self.path = path
    }

    var canGoBack: Bool { path.isEmpty == false }

    /// Switches sidebar destination. The stack is always reset, including when the same
    /// section is re-selected, so a section is never entered part-way down a stack.
    func select(_ section: AppSection) {
        self.section = section
        path.removeAll()
    }

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard canGoBack else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
