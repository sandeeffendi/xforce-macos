//
//  GraphScreen.swift
//  xforce
//

import SwiftUI

struct GraphScreen: View {
    @Environment(Router.self) private var router
    @State private var viewModel = GraphViewModel()

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            PlaceholderView(
                title: "Graph View",
                message: "A map of how the concepts you have explained connect to each other. Placeholder for now.",
                systemImage: AppSection.graph.systemImage
            )

            if router.canGoBack {
                Button("Back") { router.pop() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.windowBackground)
        .navigationTitle(AppSection.graph.title)
        .task { viewModel.load() }
    }
}

#Preview("Light") {
    GraphScreen()
        .environment(Router())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    GraphScreen()
        .environment(Router())
        .preferredColorScheme(.dark)
}
