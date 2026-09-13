//
//  GraphScreen.swift
//  xforce
//

import SwiftUI

/// The map of what the learner understands: every concept in the ontology, drawn where it was
/// authored to sit and coloured by how well it is understood.
///
/// The screen reaches the content and the store and nothing else. No model is consulted here,
/// deliberately: reviewing your own progress must never be gated on whether Apple Intelligence
/// is available on this Mac.
///
/// Split in two the way every screen is, because `@Environment` is not readable when the
/// `@State` view model's initial value is computed.
struct GraphScreen: View {
    @Environment(ContentService.self) private var content
    @Environment(SchedulingService.self) private var scheduling

    var body: some View {
        GraphScreenContent(content: content, scheduling: scheduling)
    }
}

private struct GraphScreenContent: View {
    @State private var viewModel: GraphViewModel

    init(content: ContentService, scheduling: SchedulingService) {
        _viewModel = State(initialValue: GraphViewModel(content: content, scheduling: scheduling))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.none) {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message):
                PlaceholderView(
                    title: "The map could not be drawn",
                    message: message,
                    systemImage: "exclamationmark.triangle"
                )
                .padding(Theme.Spacing.xLarge)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                ConceptGraphView(nodes: viewModel.nodes, edges: viewModel.edges)

                Divider()

                MasteryLegend()
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
        .environment(ContentService())
        .environment(SchedulingService.inMemory())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    GraphScreen()
        .environment(ContentService())
        .environment(SchedulingService.inMemory())
        .preferredColorScheme(.dark)
}
