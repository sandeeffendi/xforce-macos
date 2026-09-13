//
//  ExplainScreen.swift
//  xforce
//

import SwiftUI

struct ExplainScreen: View {
    @Environment(Router.self) private var router
    @State private var viewModel = ExplainViewModel()

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            PlaceholderView(
                title: "Explain what you're learning",
                message: "Say a concept back in your own words. This screen is a placeholder until the product requirements land.",
                systemImage: AppSection.explain.systemImage
            )

            // Navigation goes through the router, never through NavigationLink(destination:).
            Button("Open Graph View") {
                router.navigate(to: .graph)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.windowBackground)
        .navigationTitle(AppSection.explain.title)
        .task { viewModel.load() }
    }
}

#Preview("Light") {
    ExplainScreen()
        .environment(Router())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ExplainScreen()
        .environment(Router())
        .preferredColorScheme(.dark)
}
