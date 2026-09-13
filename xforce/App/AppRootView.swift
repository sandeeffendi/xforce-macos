//
//  AppRootView.swift
//  xforce
//

import SwiftUI

/// The main window shell: sidebar for sections, detail stack for routes.
struct AppRootView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router

        NavigationSplitView {
            List(AppSection.allCases, selection: selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            // Exactly one navigationDestination in the app: every push resolves here.
            NavigationStack(path: $router.path) {
                RouteBuilder.view(for: router.section.rootRoute)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteBuilder.view(for: route)
                    }
            }
        }
    }

    /// Routes sidebar selection through `Router.select(_:)` so the detail stack is reset,
    /// rather than binding to `section` directly and bypassing that rule.
    private var selectedSection: Binding<AppSection?> {
        Binding(
            get: { router.section },
            set: { newValue in
                guard let newValue else { return }
                router.select(newValue)
            }
        )
    }
}

#Preview("Light") {
    AppRootView()
        .environment(Router())
        .environment(ContentService())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    AppRootView()
        .environment(Router())
        .environment(ContentService())
        .preferredColorScheme(.dark)
}
